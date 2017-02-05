'use strict';

var AWS = require('aws-sdk');
AWS.config.region = 'ap-northeast-1';

function ec2Start(instanceId, cb){
  var ec2 = new AWS.EC2();
  var params = {
    InstanceIds: [instanceId]
  };

  ec2.startInstances(params, function(err, data) {
    if (!!err) {
      console.log('start minecraft server instance: error');
      console.log(err, err.stack);
    } else {
      console.log('start minecraft server instance: success');
      console.log(data);
    }
    cb(!err);
  });
}

function findMinecraftInstance(cb) {
  var ec2 = new AWS.EC2();
  var params = {
    Filters: [
      {
        Name: 'tag:Name',
        Values: ['minecraft']
      }
    ]
  }

  ec2.describeInstances(params, function(err, data) {
    if (!!err) {
      console.log('describe minecraft server instance: error');
      console.log(err, err.stack);
    } else {
      console.log('describe minecraft server instance: success');
      console.log(data);
      if (data.Reservations[0] && data.Reservations[0].Instances[0]) {
        cb(data.Reservations[0].Instances[0].InstanceId);
      }
    }
  });
}

exports.handler = function(event, context) {
  console.log('start minecraft server instance: start');
  findMinecraftInstance(function (instanceId) {
    ec2Start(instanceId, function(success) {
      context.done(null, 'start minecraft server instance: '+(success ? 'done' : 'error'));
    });
  });
};

/*
ROLE
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "ec2:StartInstances"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*",
        "arn:aws:ec2:*"
      ]
    }
  ]
}
*/
