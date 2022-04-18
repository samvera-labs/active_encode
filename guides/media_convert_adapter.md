# MediaConvertAdapter


To use active_encode with MediaConvert, you will need:

* An AWS account that has access to create MediaConvert jobs
* An AWS [IAM service role that has access to necessary AWS resources](https://docs.aws.amazon.com/mediaconvert/latest/ug/iam-role.html).
* An S3 bucket to store source files
* An S3 bucket to store derivatives (recommended to be separate)
* Existing [MediaConvert Output presets](https://docs.aws.amazon.com/mediaconvert/latest/ug/creating-preset-from-scratch.html) to define your outputs (eg desired HLS adaptive variants)
* EventBridge/Cloudfront setup to store output (can be automatically created by code we include here)
* You have to add these gems to your project Gemfile, that are required for
 the mediaconvert adapter but not included as active_encode dependencies:
 * aws-sdk-cloudwatchevents
 * aws-sdk-cloudwatchlogs
 * aws-sdk-mediaconvert
 * aws-sdk-s3

You may find this tutorial helpful to create the AWS resources you need, or debug the process: https://github.com/aws-samples/aws-media-services-simple-vod-workflow (mainly the firsst two modules).

## Note: No Technical Metadata

This adapter does _not_ perform input characterization or fill out technical metadata in the encoding job `input` object. technical metadata in `encode.input` such as `width`, `duration`,
or `video_codec` will be nil.

## CloudWatch and EventBridge setup, optionally with setup!

[AWS Elemental MediaConvert](https://aws.amazon.com/mediaconvert/) doesn't provide detailed
output information in the job description that can be pulled directly from the service.
Instead, it provides that information in a job status notification when the job
status changes to `COMPLETE`. The only way to capture that notification is through an [Amazon
Eventbridge](https://aws.amazon.com/eventbridge/) rule that forwards the status change
notification to another service for capture and/or handling -- for instance a CloudWatch Logs]
(https://aws.amazon.com/cloudwatch/) log group.

`ActiveEncode::EngineAdapters::MediaConvert` is written to get detailed output information from just such a setup, a CloudWatch log group that has been set up to receive MediaConvert job status `COMPLETE` notifications via an EventBridge rule.

We proide a method to create this CloudWatch and EventBridge infrastructure for you, the `#setup!` method.

```ruby
ActiveEncode::Base.engine_adapter = :media_convert
ActiveEncode::Base.engine_adapter.setup!
```

The active AWS user/role when calling the `#setup!` method will require permissions to create the
necessary CloudWatch and EventBridge resources.

The `setup!` task will create an EventBridge rule name and CloudWatch log group name based on the MediaConvert queue setting, by default `"Default"`. So:
* EventBridge rule: `active-encode-mediaconvert-Default`
* Log group name: `/aws/events/active-encode/mediaconvert/Default`

The names chosen will respect the `log_group` and `queue` config though, if set.

## Configuration

Some parameters are set as (typically global) configuration, while others are passed in as parameters to `create`. Here we'll discuss the configuration.


* `role`. Required. An IAM role that the MediaConvert job will run under. This is [required by MediaConvert](https://docs.aws.amazon.com/mediaconvert/latest/ug/iam-role.html), it can't just use your current AWS credentials.

* `output_bucket`. Required.  An S3 bucket name, all output will be written to this bucket, at a path prefix specified in the `create` call.

* `log_group`. Optional, unusual. Specify the name of the CloudWatch log group to use for logging. By default, will be constructed automatically from the MediaConvert queue to use.

* `queue`. Optional, unusual. Specify the name of the [MediaConvert queue](https://docs.aws.amazon.com/mediaconvert/latest/ug/working-with-queues.html) to use. By default it will use the MediaConvert default, called `"Default"`. Ordinarily there is no reason to set this.

```ruby
ActiveEncode::Base.engine_adapter = :media_convert

ActiveEncode::Base.engine_adapter.role = 'arn:aws:iam::11111111111111:role/my-role-name'
ActiveEncode::Base.engine_adapter.output_bucket = 'my-bucket-name'
```


## Input options, and the masterfile_bucket

The adapter can take a local file as argument (via `file://` URL or any other standard way for ActiveEncode), _or_ an `s3://` URL.

The input, whether local file _or_ remote S3 file, is normally _copied_ to a random-string-path location on the `masterfile_bucket`, and then that copy is used as input for the MediaConvert process.  Unless the input is already an `s3://` URL located in the `masterfile_bucket`, then it is just used.


```ruby
ActiveEncode::Base.create(
  "file://path/to/file.mp4",
  {
    masterfile_bucket: "my-masterfile-bucket"
    output_prefix: "path/to/output/base_name_of_outputs",
    outputs: [
      { preset: "my-hls-preset-high", modifier: "_high" },
      { preset: "my-hls-preset-medium", modifier: "_medium" },
      { preset: "my-hls-preset-low", modifier: "_low" }
    ]
  }
)
# your input will be COPIED to my-masterfile-bucket and that copy passed
# as an input to the MediaConvert operation.
```

However, if you pass the `use_original_url` bucket, then an `s3://` input URL you pass in will _not_ be copied to `masterfile_bucket`, but passed direct as input to the MediaConvert process.

```ruby
ActiveEncode::Base.create(
  "s3://some-other-bucket/path/to/file.mp4",
  {
    masterfile_bucket: "my-masterfile-bucket"
    use_original_url: true,
    output_prefix: "path/to/output/base_name_of_outputs",
    outputs: [
      { preset: "my-hls-preset-high", modifier: "_high" },
      { preset: "my-hls-preset-medium", modifier: "_medium" },
    ]
  }
)
# the S3 input will be used directly as input to the MediaConvert process,
# it will not be copied to the masterfile_bucket first.
```

Only in this case of `use_original_url` and an `s3://` input source, the `masterfile_bucket` argumetn can be ommitted, since it will be used.

## AWS Auth Credentials

The adapter, when interacting with AWS services, will interact with AWS using the [current AWS credentials looked up from environment](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html#aws-ruby-sdk-setting-credentials) in the standard way, such as the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` [environmental variables](https://docs.aws.amazon.com/sdkref/latest/guide/environment-variables.html), or [on disk at in a credentials file](https://docs.aws.amazon.com/sdkref/latest/guide/file-format.html).

The IAM identity, in order to issue MediaConvert jobs and get output information from CloudWatch, will need the following permissions, such as in this example policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "mediaconvertActions",
      "Effect": "Allow",
      "Action": "mediaconvert:*",
      "Resource": "*"
    },
    {
      "Sid": "iamPassRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::111122223333:role/MediaConvertRole"
    },
    {
      "Sid": "logsStartQuery",
      "Effect": "Allow",
      "Action": "logs:StartQuery",
      "Resource": "*"
    },
    {
      "Sid": "logsGetQuery",
      "Effect": "Allow",
      "Action": "logs:GetQueryResult",
      "Resource": "*"
    },
  ]
}
```

Where the `iamPassRole` resource is the role you will pass in the `role` configuration. The `logsStartQuery` and `logsGetQuery` permissions could probably additionally be limited to the specific CloudWatch log group.

MediaConvert necessarily [requires you to pass a separate IAM role](https://docs.aws.amazon.com/mediaconvert/latest/ug/iam-role.html) that will be used by the actual MediaConvert operation -- the `role` config for this adapter. That role will need this permission:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "execute-api:Invoke",
                "execute-api:ManageConnections"
            ],
            "Resource": "arn:aws:execute-api:*:*:*"
        }
    ]
}
```

In addition to read/write access to the relevant S3 buckets.

Also see [this tutorial](https://github.com/aws-samples/aws-media-services-simple-vod-workflow/blob/master/1-IAMandS3/README.md#1-create-an-iam-role-to-use-with-aws-elemental-mediaconvert)


