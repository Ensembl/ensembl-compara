#!/usr/bin/env python3

# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


import sys
import time
from datetime import datetime, date
import json

def api_build_run_last_hour(x):
    return x['state'] != 'canceled' and \
                         x['event_type'] == 'api' and \
                         (x['finished_at'] == None or \
                          float((datetime.fromtimestamp(time.time()) - datetime.strptime(x['finished_at'],'%Y-%m-%dT%H:%M:%SZ')).total_seconds())/3600 < 1.0)

builds = list(filter(api_build_run_last_hour, json.load(sys.stdin)['builds']))
print(len(builds) > 0)
