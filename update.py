# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "beautifulsoup4",
#     "requests",
# ]
# ///

from io import FileIO
from pathlib import Path
import sqlite3
import configparser
import requests
import itertools
import tempfile
import collections
import subprocess
from bs4 import BeautifulSoup
from typing import NamedTuple
import shutil
import json
import multiprocessing as mp
import time
from urllib3.util.retry import Retry

from requests.cookies import RequestsCookieJar
import requests.adapters


class Version(NamedTuple):
    major: str
    minor: str
    patch: str


sem = mp.Semaphore()
session = requests.Session()


def get_version_from_filename(file_name: str):
    name = file_name.split(".")[0]
    start_index = name.rfind("v") + 1
    version_str = name[start_index:]
    patch = version_str[-1]
    minor = version_str[-2]
    major = version_str[:-2]
    return Version(major, minor, patch)


def get_modartt_cookies_for_db_path(path: Path) -> dict[str, str]:
    path = f"file:{str(path)}?immutable=1"
    con = sqlite3.connect(path, uri=True)
    cur = con.cursor()
    cookies = cur.execute(
        'SELECT name, value, host FROM moz_cookies WHERE name="modartt"'
    )
    return {name: value for (name, value, host) in cookies.fetchall()}


def get_db_paths():
    config_folder = Path.home() / ".mozilla" / "firefox"
    config_path = config_folder / "profiles.ini"
    config = configparser.ConfigParser()
    config.read(config_path)
    db_paths = [
        config_folder / config[section]["Path"] / "cookies.sqlite"
        for section, val in config.items()
        if section != "DEFAULT" and section != "General"
    ]
    return db_paths


def get_pianoteq_file_names(html: str):
    soup = BeautifulSoup(html, "html.parser")
    links = soup.find_all("a", class_="download mrtc-download")
    file_names: list[str] = [
        link.get("data-mrt-file")
        for link in links
        if link.get("title").startswith("Linux")
    ]
    file_names_dict = {get_version_from_filename(name): name for name in file_names}
    return file_names_dict


def get_actual_download_link(
    filename: str,
):
    headers = {
        "modartt-json": "request",
        "origin": "https://www.modartt.com",
        "content-type": "application/json; charset=UTF-8",
        "accept": "application/json, text/javascript, */*",
        "referer": "https://www.modartt.com/user_area",
    }
    raw_data = {"file": filename, "get": "url"}

    url = f"https://www.modartt.com/api/0/download"
    r = session.post(
        url,
        json=raw_data,
        headers=headers,
        allow_redirects=True,
    )
    real_url: str = json.loads(r.text)["url"]
    return real_url


def get_file_hash(url: str):
    sem.acquire()
    with tempfile.NamedTemporaryFile(mode="wb", delete_on_close=False) as f:
        path = f.name
        print(url)
        with session.get(url, stream=True) as r:
            r.raise_for_status()
            src: FileIO = r.raw
            shutil.copyfileobj(src, f)
            # with src:
            # while True:
            # chunk = src.read(8192)
            # if not chunk:
            # break
            # f.write(chunk)
            # for chunk in src.read():
            # f.write(chunk)
        res = subprocess.run(
            ["nix", "hash", "file", path], text=True, stdout=subprocess.PIPE
        )
        hash = res.stdout
        print(f"{url.split('/')[-1]}: {hash}")
    return hash


def get_html(url: str):
    r = session.get(url)
    html = r.text
    return html


def pacemaker(sem):
    while True:
        time.sleep(0.5)
        sem.release()


def main():
    db_paths = get_db_paths()
    cookies = collections.ChainMap(
        *list(get_modartt_cookies_for_db_path(db_path) for db_path in db_paths)
    )
    cookies = dict(cookies)
    session.cookies.update(cookies)
    retry = Retry(connect=3, backoff_factor=0.5)
    adapter = requests.adapters.HTTPAdapter(max_retries=retry)
    session.mount("http://", adapter)
    session.mount("https://", adapter)

    url = r"https://www.modartt.com/user_area?tab=downloads"
    html = get_html(url)
    file_names = get_pianoteq_file_names(html)
    download_urls = {
        key: get_actual_download_link(val) for key, val in file_names.items()
    }

    ticker = mp.Process(target=pacemaker, args=(sem,), daemon=True)
    ticker.start()
    with mp.Pool(1) as p:
        versions, args = list(zip(*download_urls.items()))
        hashes = p.map(get_file_hash, args)
    print(hashes)
    # print(hash)


if __name__ == "__main__":
    main()
