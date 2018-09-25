# Buildpack Development

## Caching of compiled artifacts

Requires an S3 bucket with a public-by-default policy:

```json
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "AllowPublicRead",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::kong-on-heroku",
                "arn:aws:s3:::kong-on-heroku/*"
            ]
        }
    ]
}
```

Make sure the templator app has the AWS CLI install:

```bash
heroku buildpacks:add --index=1 mars/awscli
heroku config:set \
  AWS_ACCESS_KEY_ID=xxxxx \
  AWS_SECRET_ACCESS_KEY=yyyyy \
  AWS_DEFAULT_REGION=us-west-1
git commit --allow-empty -m 'Add AWS CLI buildpack'
git push heroku master
```

`heroku run bash` to app, and then capture the artifacts:

```bash
ARCHIVE_NAME=kong-runtime-v5.1.1.tgz
tar czfv $ARCHIVE_NAME ./kong-runtime
aws s3 cp $ARCHIVE_NAME s3://kong-on-heroku/
```
