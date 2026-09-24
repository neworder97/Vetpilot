#!/usr/bin/env python3
"""Use the execution host's advertised proxy when present; no fixed proxy ports."""
import os,sys,subprocess,urllib.parse
u=urllib.parse.urlparse(os.environ.get('HTTPS_PROXY',''))
if u.hostname and u.port:
 os.environ['GRADLE_OPTS']=f'-Dhttps.proxyHost={u.hostname} -Dhttps.proxyPort={u.port} -Dhttp.proxyHost={u.hostname} -Dhttp.proxyPort={u.port}'
raise SystemExit(subprocess.call([os.environ.get('GRADLE_BIN','gradle'),'--no-daemon',*sys.argv[1:]]))
