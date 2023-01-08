## CI/CD

We use [aliyun](https://www.aliyun.com/) and [aws](https://www.amazonaws.cn/en/) as cloud infrastructure. This repo includes cicd tools we've used so far.

* circleci
* codebuild - aws
* github
* gitlab.cn
* jenkins

Right now, we use[EKS](https://www.amazonaws.cn/en/eks/) to run our apps. The general CI/CD workflow is:

1. Push code to remote repo
2. Test code in CI
3. Docker build image based on repo's Dockerfile
4. Push image to aws [ECR](https://docs.amazonaws.cn/en_us/AmazonECR/latest/userguide/what-is-ecr.html)
5. kubectl apply the yaml files to roll update the apps. I.e, pull latest image from ECR and rebuild the containers in k8s.

This repo is only for a demo purpose. If you want to use this repo for your app, code from this repo should be tweaked.

You may also need to add environment variables to the selected tools for CI/CD.

## AWS Zero Deployment Downtime

We use aws [alb](https://docs.amazonaws.cn/en_us/elasticloadbalancing/latest/application/introduction.html) to configure ingress, and have two pods enabled for this test service `jiameng-api-dev` here.

Based on tests we've done, [alb pod_readiness_gate](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/pod_readiness_gate/) reduces the Downtime, but does not 100% remove the downtime.

We write one script to test it. See `aws_alb_test.sh`. It uses [describe-target-health](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/elbv2/describe-target-health.html) to get target healthy state before sending requests to the Go app.

We also [enabled alb access log](https://docs.amazonaws.cn/en_us/elasticloadbalancing/latest/application/enable-access-logging.html) to track which targets are serving our test requests.

When `alb pod_readiness_gate` is not enabled, there could be no `healthy` targets in the target group. Targets can be in either `draining` or `initial` state, but no `healthy` state.

NO healthy targets
![NO healthy targets](https://yanlin-public.s3.cn-northwest-1.amazonaws.com.cn/github/aws-no-healthy-targets.jpeg)

With `alb pod_readiness_gate` enabled, it is guarenteed that there's always at least one health target available for the target group.

### 5xx error result

Ideally, we can expect zero downtime with `alb pod_readiness_gate` enabled. But in reality, we can still observe 5xx errors.

<details>
    <summary>5xx errors with healthy targets</summary>

    16 starts kube pod [2023-01-07 17:22:40.926437] ;
    NAME                               READY   STATUS        RESTARTS   AGE   IP           NODE                                            NOMINATED NODE   READINESS GATES
    jiameng-api-dev-7cf849584f-kh7vk   1/1     Terminating   0          39m   10.0.2.61    ip-10-0-2-240.cn-northwest-1.compute.internal   <none>           1/1
    jiameng-api-dev-7fccd97f9d-d66qt   1/1     Running       0          17s   10.0.2.134   ip-10-0-2-240.cn-northwest-1.compute.internal   <none>           1/1
    jiameng-api-dev-7fccd97f9d-vrk9p   1/1     Running       0          35s   10.0.1.222   ip-10-0-1-89.cn-northwest-1.compute.internal    <none>           1/1
    {
        "TargetHealthDescriptions": [
            {
                "Target": {
                    "Id": "10.0.1.222",
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
            }
        ]
    }
    16 starts curl  [2023-01-07 17:22:42.554251] ;
    <html>
    <head><title>504 Gateway Time-out</title></head>
    <body>
    <center><h1>504 Gateway Time-out</h1></center>
    </body>
    </html>
    ;
    16 ends curl [2023-01-07 17:22:52.765480];

</details>

Above example shows two `draining` targets and two `healthy` targets exist in the same time. It looks like one of the two `draining` targets is still receving traffic, otherwise we should get `200` from those other two `healthy` targets.

To double confirm, we find above request's alb access log record. Sensitive data has been replaced with `xxxxxxxx`.

```
h2 2023-01-07T09:22:52.872365Z app/k8s-apidev-95472999b0/xxxxxxxxxx 202.102.17.226:24502 10.0.2.61:1325 -1 -1 -1 504 - 49 202 "GET https://example-api.cn:443/prefix-jiameng-api/ HTTP/2.0" "curl/7.79.1" ECDHE-RSA-XXXX-GCM-SHA256 TLSv1.2 arn:aws-cn:elasticloadbalancing:cn-northwest-1:xxxxxxx:targetgroup/k8s-dev-jiamenga-edb70a94b9/081fxxxxxxxx "Root=1-63b939e2-312611fa7a64f07e63d24099" "exxample-api.cn" "arn:aws-cn:acm:cn-northwest-1:xxxxxxx:certificate/e38c0d37-5c2f-4988-81c0-xxxxxxxx" 1 2023-01-07T09:22:42.870000Z "forward" "-" "-" "10.0.2.61:1325" "-" "-" "-"
```

China is in UTC+8, and alb log is using UTC, so there're 8 hours difference between our shell script screen and alb access log.

Anyway, we can see load balancer has routed request to this `draining` target `10.0.2.61:1325`. `target_status_code` is `-`, and `elb_status_code` is `504`. It means connection between load balancer and this target `10.0.2.61` has been closed, then load balancer returns 504 to client. These fields explanation can be found at [access logs](https://docs.amazonaws.cn/en_us/elasticloadbalancing/latest/application/load-balancer-access-logs.html). It makes sense this connection is closed since this target `10.0.2.61`'s pod `jiameng-api-dev-7cf849584f-kh7vk` is in `terminating` status, and this pod can exit very quickly.

According to [Register targets](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-register-targets.html)

> The load balancer stops routing requests to a target as soon as you deregister it.

Apparently, in above test cases, the load balancer keeps routing requests to the draining(deregistered) targets, even in the meantime, there're healthy targets available.

However, according to [Deregistration delay](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html#deregistration-delay)

> If a deregistering target terminates the connection before the deregistration delay elapses, the client receives a 500-level error response.

These 5xx errors become reasonable since our deregistering(draining) targets have closed the connection due to their pods being terminated, and deregistration delay is not elapsed yet.

### 5xx error cause

**Load balancer has routed traffic to `draining` state target, but the connection between load balancer and the `draining` target has been closed due to target's pod being terminated.**

### 5xx error solution

To fix this issue, **we want to keep the `draining` targets always available to be used. In other words, if one target is in `draining` state, its associated pod should not exit. In this way, we hope the connection between load balancer and `draing` target will not be closed unless target's [Connection idle timeout](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html#connection-idle-timeout) has reached.**

So we just prevent the old pods from being terminated quickly. In order to achieve this goal, we add [prestop hook](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/) to k8s deployment file. Check detail at `/deploy/k8s_deployment.yaml`

```
terminationGracePeriodSeconds: 50
lifecycle:
    preStop:
        exec:
            command: ["/bin/sh", "-c", "sleep 40"]
```

This will prevent the old pods from being terminated quickly, and can stay available for 40 seconds.

Now we run the test script again, and this time, we don't see 5xx errors, but we can observe result like below.

<details>
    <summary>Draining target without its associated pod available</summary>

    35 starts kube pod [2023-01-06 19:41:34.769521] ;
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
    35 starts curl  [2023-01-06 19:41:36.510725] ;
    ok;
    35 ends curl [2023-01-06 19:41:36.741279];
</details>

Target `"10.0.1.109"` is in `draining` target, but its pod is already terminated after 40 seconds. Even though we don't get 5xx error this time, there's still a chance that the `draining` target can be used for traffic from past test experience.

According to [Deregistration delay](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html#deregistration-delay), 

> The initial state of a deregistering target is draining. By default, the load balancer changes the state of a deregistering target to unused after 300 seconds. 

So here we want to decrease target Deregistration delay time to make sure pod could live longer than its `draining` state target.

For test purpose, we set Deregistration delay time to be 35 seconds for target group.

**Now Pod can live for 40 seconds before terminated, and its target can stay in `draining` state for maximum 35 seconds.** We should expect to see result that one Pod is still available, but its associated target has become `unused`.

<details>
    <summary>Pod lives without its associated target</summary>

    30 starts kube pod [2023-01-06 20:11:48.745410] ;
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
    30 starts curl  [2023-01-06 20:11:50.392375] ;
    ok;
    30 ends curl [2023-01-06 20:11:50.606315];
</details>

We can see this pod `"10.0.1.99"` lives, but it doesn't have one associated target now. This is exactly what we want to see!

**To sum up, we want to keep pod living longer than its associated target**, i.e, for these three values

- terminationGracePeriodSeconds for pod >
- preStop for pod >
- Deregistration delay for target group

The higher one should have larger value than the lower one.

For real projects, we may want to increase the overall time, instead of `35 seconds` for Deregistration delay. Saying, we have lengthy requests taking maximum 300 seconds, such as querying a big database, then we may want to increase the Deregistration delay to be above `300` seconds, then your in-flight requests for `draining` targets can have enough time to complete.

But based on our above test cases, the `draining` targets can still take new traffic, so theoretically, the delay value doesn't guarantee in-flight requests are always completed successfully.

[This blog](https://blog.davidh83110.com/blog/2021-06-24-eks-awslbcontroller-gracefully-rolling-update/) has pointed out [Connection idle timeout](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html#connection-idle-timeout) should be taken into above consideration too, that `Deregistration delay > application's own timeout > Connection idle timeout`.

In an ideal world, it is a good practice to keep above value order. Client receives `504` when `Connection idle timeout` has reached. On the other hand, it might be confusing for client to receive `504`, since `application's own timeout` has not reached yet.

In real scenarios, one project might want to keep `application's own timeout < Connection idle timeout < Deregistration delay`. In such case, client prefers to receive `502` when `application's own timeout` has reached. At least, the error has come as expected from app's view, even though the status code is not `504`.

**Big thanks to aws solution architect [chenxqdu](https://github.com/chenxqdu) for above discussion ^_^**
