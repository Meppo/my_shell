#!/bin/bash

curl -X POST -H 'Host:192.168.0.1' \
    -H 'token_id: 429bc42232f4da74510517f8ded76dac'\
    -H 'X-Requested-With: XMLHttpRequest'\
    -H 'Accept-Language: en-US,en;q=0.5'\
    -H 'Accept-Encoding: gzip, deflate'\
    -H 'Connection: keep-alive'\
    -H 'Content-Length: 0'\
    -b'a=b'\
    -e 'http://192.168.0.1/new_index.htm?token_id=429bc42232f4da74510517f8ded76dac'\
    http://192.168.0.1/app/devices/webs/getdeviceslist.cgi
#    -b'Qihoo_360_login=fb359aacd0de703d1c104b9af98c22de'\
#Accept: application/json, text/javascript, */*; q=0.01
#Accept-Language: en-US,en;q=0.5
#Accept-Encoding: gzip, deflate
#token_id: 429bc42232f4da74510517f8ded76dac
#X-Requested-With: XMLHttpRequest
#Referer: http://192.168.0.1/new_index.htm?token_id=429bc42232f4da74510517f8ded76dac
#Cookie: Qihoo_360_login=fb359aacd0de703d1c104b9af98c22de
#Connection: keep-alive
#Content-Length: 0
