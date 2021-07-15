#!/usr/bin/env python3

import logging
import os
import sys
from concurrent import futures

import boto3
import requests
from jinja2 import Template
from requests.adapters import HTTPAdapter

import utils

logging.basicConfig(stream=sys.stdout, level=logging.INFO)


def upload_directory(
    directory: str,
    prefix: str,
    bucket: str = os.getenv("AWS_BUCKET_REPOS"),
    boto3_session: boto3.Session = boto3.Session(),
) -> int:
    ret = 0
    s3 = boto3_session.client("s3")

    def error(e: Exception) -> None:
        raise e

    def walk_directory(directory: str) -> str:
        for root, _, files in os.walk(directory, onerror=error):
            for f in files:
                yield os.path.join(root, f)

    def upload_file(filename: str):
        s3.upload_file(
            Filename=filename,
            Bucket=bucket,
            Key=prefix + "/" + os.path.relpath(filename, directory),
        )

    with futures.ThreadPoolExecutor() as executor:
        upload_task = {}

        for filename in walk_directory(directory):
            upload_task[executor.submit(upload_file, filename)] = filename

        for task in futures.as_completed(upload_task):
            try:
                task.result()
            except Exception as e:
                logging.error(
                    f"Exception {e} encountered while uploading file"
                    f"{upload_task[task]}"
                )
                ret = 1
    return ret


def create_repo(repodir: str) -> int:
    return utils.run_cmd(cmd=["createrepo_c", repodir])


def test_repo(bucket: str, region: str, id: int) -> int:
    with open("/etc/yum.repos.d/automotive.repo", "w") as repofile:
        repofile.write(
            Template(
                open(
                    os.path.join(
                        (os.path.dirname(os.path.realpath(__file__))),
                        "yumrepo.j2",
                    ),
                ).read()
            ).render(bucket=bucket, region=region, id=id)
        )
    return utils.run_cmd(cmd=["sudo", "dnf", "makecache", "--repo=automotive"])


def main() -> int:
    ret0 = 0
    repodir = "/var/lib/repos"
    os.mkdir(f"{repodir}")

    s = requests.Session()
    s.mount("http://mirror.centos.org", HTTPAdapter(max_retries=5))

    with open("./package_list/c8s-image-manifest.txt") as im:
        for p in im.readlines():
            repositories = ["BaseOS", "AppStream"]
            arches = ["aarch64", "noarch"]
            for repo in repositories:
                for arch in arches:
                    pkg = f"{p.strip()}.{arch}.rpm"
                    r = s.get(
                        url=(
                            f"http://mirror.centos.org/centos/8-stream/{repo}/"
                            f"aarch64/os/Packages/{pkg}"
                        ),
                        allow_redirects=True,
                    )
                    if r.status_code == 200:
                        with open(f"{repodir}/{pkg}", "wb") as f:
                            f.write(r.content)
                        logging.debug(f"{pkg} downloaded")
                        break  # pkg was found and was downloaded
                else:  # pkg was not found in any of the arches
                    continue  # continue to next repository.
                break  # pkg was found and was downloaded
            else:  # pkg was not found in any of the arches*repositories
                logging.error(f"{p.strip()} was not found")
                ret0 = 1

    ret1 = create_repo(repodir)

    ret2 = upload_directory(
        directory=repodir,
        prefix=os.getenv("GITHUB_RUN_ID"),
    )

    ret3 = test_repo(
        bucket=os.getenv("AWS_BUCKET_REPOS"),
        region=os.getenv("AWS_REGION"),
        id=os.getenv("GITHUB_RUN_ID"),
    )

    with open("/etc/yum.repos.d/automotive.repo") as f:
        logging.debug(f.read())

    if ret0 == 0 and ret1 == 0 and ret2 == 0 and ret3 == 0:
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
