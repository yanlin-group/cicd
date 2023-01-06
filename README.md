## CI/CD

We use [aliyun](https://www.aliyun.com/) and [aws](https://www.amazonaws.cn/en/) as cloud infrastructure. This repo focuses on cicd tools we've tried so far.

[EKS](https://www.amazonaws.cn/en/eks/) is used to run our apps. The general CI/CD workflow is:

1. Push code to remote repo
2. Test code in CI
3. Docker build image based on repo's Dockerfile
4. Push image to aws [ECR](https://docs.amazonaws.cn/en_us/AmazonECR/latest/userguide/what-is-ecr.html)
5. kubectl apply the yaml files to roll update the apps. I.e, pull latest image from ECR and rebuild the containers in k8s.

This repo is only for a demo purpose. If you want to use this repo for your app, code from this repo should be tweaked.

You may also need to add environment variables to the selected tools for CI/CD.

## AWS Zero Deployment Downtime

We use aws [alb](https://docs.amazonaws.cn/en_us/elasticloadbalancing/latest/application/introduction.html) to configure ingress.

Based on tests we've done, [alb pod_readiness_gate](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/pod_readiness_gate/) reduces the Downtime, but does not 100% remove the downtime.

We write one script to test it. See `aws_alb_test.sh`. It uses [describe-target-health](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/elbv2/describe-target-health.html) to get target healthy state before sending requests to the Go app.

When `alb pod_readiness_gate` is not enabled, there could be no `healthy` targets in the target group. Targets can be in either `draining` or `initial` state, but no `healthy` state.

NO healthy targets
![NO healthy targets](https://yanlin-public.s3.cn-northwest-1.amazonaws.com.cn/github/aws-no-healthy-targets.jpeg)

With `alb pod_readiness_gate` enabled, it is guarenteed that there's always at least one health target available for the target group.

Ideally, we can expect zero downtime. But in reality, we can still observe 5xx errors.

<details>
    <summary>5xx errors with healthy targets example one</summary>

    15 starts kube pod [2023-01-06 18:38:37] ;
    NAME                               READY   STATUS    RESTARTS   AGE     IP           NODE                                            NOMINATED NODE   READINESS GATES
    jiameng-api-dev-76486b6497-7pj88   1/1     Running   0          8m41s   10.0.2.61    ip-10-0-2-240.cn-northwest-1.compute.internal   <none>           1/1
    jiameng-api-dev-7cf4b975b4-5d6jb   1/1     Running   0          21s     10.0.1.109   ip-10-0-1-89.cn-northwest-1.compute.internal    <none>           1/1
    jiameng-api-dev-7cf4b975b4-f6pkr   1/1     Running   0          4s      10.0.2.45    ip-10-0-2-240.cn-northwest-1.compute.internal   <none>           0/1
    {
        "TargetHealthDescriptions": [
            {
                "Target": {
                    "Id": "10.0.2.45",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1b"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "initial",
                    "Reason": "Elb.RegistrationInProgress",
                    "Description": "Target registration is in progress"
                }
            },
            {
                "Target": {
                    "Id": "10.0.1.109",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1a"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "healthy"
                }
            },
            {
                "Target": {
                    "Id": "10.0.2.61",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1b"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "healthy"
                }
            },
            {
                "Target": {
                    "Id": "10.0.1.99",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1a"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "draining",
                    "Reason": "Target.DeregistrationInProgress",
                    "Description": "Target deregistration is in progress"
                }
            }
        ]
    }
    15 starts curl  [2023-01-06 18:38:39] ;
    <html>
    <head><title>502 Bad Gateway</title></head>
    <body>
    <center><h1>502 Bad Gateway</h1></center>
    </body>
    </html>
    ;
    15 ends curl 23-01-06 18:38:44;

</details>

Example one shows `draining` target `"10.0.1.99"` is still receiving traffic. But its pod has already exited, then we get 502.

The inital target `"10.0.2.45"` may also receive this request in this case, even we can see its `READINESS GATES` is not ready yet. With this question in mind, we move to the next example.

<details>
    <summary>5xx errors with healthy targets example two</summary>

    20 starts kube pod [2023-01-06 18:38:51] ;
    NAME                               READY   STATUS    RESTARTS   AGE   IP           NODE                                            NOMINATED NODE   READINESS GATES
    jiameng-api-dev-7cf4b975b4-5d6jb   1/1     Running   0          35s   10.0.1.109   ip-10-0-1-89.cn-northwest-1.compute.internal    <none>           1/1
    jiameng-api-dev-7cf4b975b4-f6pkr   1/1     Running   0          18s   10.0.2.45    ip-10-0-2-240.cn-northwest-1.compute.internal   <none>           1/1
    {
        "TargetHealthDescriptions": [
            {
                "Target": {
                    "Id": "10.0.2.45",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1b"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "healthy"
                }
            },
            {
                "Target": {
                    "Id": "10.0.1.109",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1a"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "healthy"
                }
            },
            {
                "Target": {
                    "Id": "10.0.2.61",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1b"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "draining",
                    "Reason": "Target.DeregistrationInProgress",
                    "Description": "Target deregistration is in progress"
                }
            },
            {
                "Target": {
                    "Id": "10.0.1.99",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1a"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "draining",
                    "Reason": "Target.DeregistrationInProgress",
                    "Description": "Target deregistration is in progress"
                }
            }
        ]
    }
    20 starts curl  [2023-01-06 18:38:53] ;
    <html>
    <head><title>502 Bad Gateway</title></head>
    <body>
    <center><h1>502 Bad Gateway</h1></center>
    </body>
    </html>
    ;
    20 ends curl 23-01-06 18:39:00;
</details>

Example two is a more clear example, that it shows the two draining targets `"10.0.1.99"` and `"10.0.2.61"` are still receiving traffic. But their pods have already exited, then we get 502. If the other two health targets get this request, we should get 200.

According to [Deregistration delay](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-target-groups.html#deregistration-delay), 

> If the deregistered target stays healthy and an existing connection is not idle, the load balancer can continue to send traffic to the target. 

Apparently, in above test cases, the draining(deregistered) targets' connection is not idle, and they are still receiving traffic.

To fix this issue, we want to keep the draining targets still available to be used. If one target is in `draining` state, then its associated pod should not exit.

So we just prevent the old pods from being terminated quickly. In order to achieve this goal, we add prestop hook to k8s deployment file. Check detail at `/deploy/k8s_deployment.yaml`

```
terminationGracePeriodSeconds: 50
lifecycle:
    preStop:
        exec:
            command: ["/bin/sh", "-c", "sleep 40"]
```

This will prevent the old pods from being terminated quickly, and can stay available for 40 seconds.

This time, we don't see 5xx errors, but we can observe result like below.

<details>
    <summary>Draining target without its associated pod available</summary>

    35 starts kube pod [2023-01-06 19:41:34] ;
    NAME                               READY   STATUS        RESTARTS   AGE   IP           NODE                                            NOMINATED NODE   READINESS GATES
    jiameng-api-dev-559b96d846-vpvhg   1/1     Terminating   0          11m   10.0.2.235   ip-10-0-2-240.cn-northwest-1.compute.internal   <none>           1/1
    jiameng-api-dev-7665d8f85f-6r46s   1/1     Running       0          47s   10.0.2.66    ip-10-0-2-240.cn-northwest-1.compute.internal   <none>           1/1
    jiameng-api-dev-7665d8f85f-z6w8v   1/1     Running       0          65s   10.0.1.99    ip-10-0-1-89.cn-northwest-1.compute.internal    <none>           1/1
    {
        "TargetHealthDescriptions": [
            {
                "Target": {
                    "Id": "10.0.2.66",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1b"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "healthy"
                }
            },
            {
                "Target": {
                    "Id": "10.0.2.235",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1b"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "draining",
                    "Reason": "Target.DeregistrationInProgress",
                    "Description": "Target deregistration is in progress"
                }
            },
            {
                "Target": {
                    "Id": "10.0.1.109",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1a"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "draining",
                    "Reason": "Target.DeregistrationInProgress",
                    "Description": "Target deregistration is in progress"
                }
            },
            {
                "Target": {
                    "Id": "10.0.1.99",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1a"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "healthy"
                }
            }
        ]
    }
    35 starts curl  [2023-01-06 19:41:36] ;
    ok;
    35 ends curl 23-01-06 19:41:36;
</details>

Target `"10.0.1.109"` is in draining target, but its pod is already terminated after 40 seconds. Even though we don't get 5xx error this time, there's still a chance that the draining target can be used for traffic from past test experience.

According to [Deregistration delay](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-target-groups.html#deregistration-delay), 

> The initial state of a deregistering target is draining. By default, the load balancer changes the state of a deregistering target to unused after 300 seconds. 

According to [Connection idle timeout](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html)

> By default, Elastic Load Balancing sets the idle timeout value for your load balancer to 60 seconds. Use the following procedure to set a different idle timeout value.

So here we want to decrease target Deregistration delay time, and idle timeout to make sure pod could live longer than its `draining` state target.

For test purpose, we set Deregistration delay time to be 35 seconds for target group, and 30 seconds for load balancer idle timeout. This is to make sure when target becomes unused, its connection should have been closed already.

Now Pod can live for 40 seconds before terminated, and its target can stay in `draining` state for only 35 seconds. We should expect to see result that one Pod is still available, but its associated target has become `unused`.

<details>
    <summary>Pod lives without its associated target</summary>

    30 starts kube pod [2023-01-06 20:11:48] ;
    NAME                               READY   STATUS        RESTARTS   AGE   IP           NODE                                            NOMINATED NODE   READINESS GATES
    jiameng-api-dev-6cd554685-l46jz    1/1     Running       0          37s   10.0.2.134   ip-10-0-2-240.cn-northwest-1.compute.internal   <none>           1/1
    jiameng-api-dev-6cd554685-w49dg    1/1     Running       0          54s   10.0.1.109   ip-10-0-1-89.cn-northwest-1.compute.internal    <none>           1/1
    jiameng-api-dev-7665d8f85f-6r46s   1/1     Terminating   0          31m   10.0.2.66    ip-10-0-2-240.cn-northwest-1.compute.internal   <none>           1/1
    jiameng-api-dev-7665d8f85f-z6w8v   1/1     Terminating   0          31m   10.0.1.99    ip-10-0-1-89.cn-northwest-1.compute.internal    <none>           1/1
    {
        "TargetHealthDescriptions": [
            {
                "Target": {
                    "Id": "10.0.2.66",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1b"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "draining",
                    "Reason": "Target.DeregistrationInProgress",
                    "Description": "Target deregistration is in progress"
                }
            },
            {
                "Target": {
                    "Id": "10.0.1.109",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1a"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "healthy"
                }
            },
            {
                "Target": {
                    "Id": "10.0.2.134",
                    "Port": 1325,
                    "AvailabilityZone": "cn-northwest-1b"
                },
                "HealthCheckPort": "1325",
                "TargetHealth": {
                    "State": "healthy"
                }
            }
        ]
    }
    30 starts curl  [2023-01-06 20:11:50] ;
    ok;
    30 ends curl 23-01-06 20:11:50;
</details>

We can see this pod `"10.0.1.99"` lives, but it doesn't have one associated target now. This is exactly what we want to see.

To sum up, we need to keep pod living longer than its associated target, i.e, for these four values

- terminationGracePeriodSeconds for pod >
- preStop for pod >
- Deregistration delay for target group >
- idle timeout value for load balancer

The higher one should have larger value than the lower one.

For real projects, we may want to increase the overall time, instead of `35 seconds` for Deregistration delay.

According to [Deregistration delay](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-target-groups.html#deregistration-delay)

> We recommend that you specify a value of at least 120 seconds to ensure that requests are completed.

Big thanks to aws solution architect [chenxqdu](https://github.com/chenxqdu) for discussion, and blog [Solved - AWS LoadBalancer Controller Cannot Gracefully Rolling Update](https://blog.davidh83110.com/blog/2021-06-24-eks-awslbcontroller-gracefully-rolling-update/) for double confirmation.
