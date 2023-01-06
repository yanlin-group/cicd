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

Based on test we've done, [alb pod_readiness_gate](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/pod_readiness_gate/) is not working.

We write one script to test it. See `aws_alb_test.sh`

The big challenge for alb is there's a time deplay that a new k8s pod is already in `running` state, but its associated alb target is still in `initial` state for like 10 seconds.

This results in a time period gap that all alb targets are in either `draining` or `inital` state. No `healthy` targets are available, even though there're running pods. Then we get 5xx errors.

NO healthy targets
![NO healthy targets](https://yanlin-public.s3.cn-northwest-1.amazonaws.com.cn/github/aws-no-healthy-targets.jpeg)

5xx errors with running pods. We can see the 500 result for test run at 6 and 7, even running pods are there.
![5xx errors with running pods](https://yanlin-public.s3.cn-northwest-1.amazonaws.com.cn/github/aws-alb-500-without-sleep.jpeg)

We can also observe from above screen that the old pods are terminated/removed quicky within 2 seconds. I.e, even these old pods' alb target are still in draining state, but the old pods are already deleted.

What we can conclude so far is the target in `initial` state is not taking traffic, even its k8s pod is in `running` state. The target in `draining` state may or may not take traffic. If target in `draining` state is taking traffic, it's reasonable to return 5xx, since its associated pod has exited already.

To verify this, we add below hook to k8s deployment file. Check detail at `/deploy/k8s_deployment.yaml`
```
terminationGracePeriodSeconds: 50
lifecycle:
    preStop:
        exec:
            command: ["/bin/sh", "-c", "sleep 40"]
```

This will prevent the old pods from being terminated quickly, and can stay available for 40 seconds.

Pod terminating starts
![Pod terminating starts](https://yanlin-public.s3.cn-northwest-1.amazonaws.com.cn/github/aws-sleep-terminating-pod-start.jpg)

Pod terminating ends
![Pod terminating ends](https://yanlin-public.s3.cn-northwest-1.amazonaws.com.cn/github/aws-sleep-terminating-pod-end.jpg)

We find the time gap is between `4 starts kube  [2023-01-06 13:28:19]` and `45 starts kube  [2023-01-06 13:29:02]` for ~40 seconds. And all the curl result is 200.

It means when no `healthy` targets are available, the `draining` state targets are still taking traffic. Because this time, the `draining` state targets have running pods (in `terminating` state, but not terminated), `draining` state targets can serve the traffic well.

To take above abservation into next step, we may do some traffic track at app level to see which pod is actually serving the traffic when no healthy targets are available. Or use aws cloud trail related tools to see which alb target has been used to reroute the traffic when no healthy targets exist.

Due to our workload, we didn't do further verification. But if you are interested, feel free to share with us about what result you have verified ^

Big thanks to aws solution architect [chenxqdu](https://github.com/chenxqdu) for discussion to verify above alb zero downtime observation.
