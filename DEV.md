# Buildpack Development

## Caching of compiled artifacts

`heroku run bash` to app, and then capture the artifacts 

```bash
ARCHIVE_NAME=kong-runtime-v5.1.1.tgz
tar czfv $ARCHIVE_NAME ./kong-runtime

file=$ARCHIVE_NAME
bucket=kong-on-heroku
s3Key=xxxxx
s3Secret=yyyyy
# default regionEndpoint is "s3"
regionEndpoint=s3-us-west-1
resource="/${bucket}/${file}"
contentType="application/x-compressed-tar"
dateValue=`date -R`
stringToSign="PUT\n\n${contentType}\n${dateValue}\n${resource}"
signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3Secret} -binary | base64`
curl -X PUT -T "${file}" \
  -H "Host: ${bucket}.${regionEndpoint}.amazonaws.com" \
  -H "Date: ${dateValue}" \
  -H "Content-Type: ${contentType}" \
  -H "Authorization: AWS ${s3Key}:${signature}" \
  -H "x-amz-acl: public-read" \
  https://${bucket}.${regionEndpoint}.amazonaws.com/${file}

```
