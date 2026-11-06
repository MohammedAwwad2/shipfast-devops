# ShipFast Deployment Strategy

## 1. Deployment Strategies Comparison

| Strategy | How Traffic Moves | Rollback Speed | Extra Infrastructure Cost | Blast Radius | Effort to Operate |
|---|---|---|---|---|---|
| Recreate | All old replicas are stopped before the new replicas start. | Slow, because the old version needs to be deployed again. | Low | High, because the application experiences downtime during deployment. | Low |
| Rolling | Old replicas are gradually replaced with new replicas. Traffic continues through the available healthy replicas. | Medium, because the old version needs to be rolled out again. | Low | Medium, because users may experience issues if the new version has a problem. | Low |
| Blue-Green | The new version is deployed in a separate environment while the old version continues serving traffic. Traffic is switched to the new environment once it is ready. | Fast, because traffic can be switched back to the old environment. | High, because both environments must run simultaneously. | Low during initial rollout, because the new version is prepared before receiving production traffic. | Medium |
| Canary | A small percentage of traffic is sent to the new version first. Traffic is gradually increased if the new version performs well. | Fast, because traffic can be redirected to the old version. | Medium | Low, because only a small percentage of users are initially exposed to the new version. | High, because traffic distribution and monitoring require additional configuration. |

## 2. ShipFast Facts

ShipFast is a Node.js application that provides `/health` and `/metrics` endpoints. The application currently runs with one replica in Week 6, but we plan to increase this to two replicas to support Rolling Deployment and improve availability during updates. ArgoCD will be introduced in Week 7 to manage application deployments, while Prometheus metrics will be introduced in Week 9 to monitor application performance. The application does not use a database, which makes deployment and rollback simpler because there are no database migrations or data compatibility concerns.

## 3. Recommendation

I recommend using **Rolling Deployment** for ShipFast at its current stage.

The main reason is that ShipFast is a relatively simple application with a limited number of users. By increasing the replicas from one to two, we can replace one replica at a time while keeping the other replica available to serve requests. This helps minimize downtime without requiring a separate environment or significant additional infrastructure.

It is also easier to operate compared with Blue-Green and Canary deployments, which would introduce additional configuration and operational complexity that is not currently justified by the application's usage.

If ShipFast usage grows tenfold, I would consider moving to **Canary Deployment**. This would allow us to expose a small percentage of production traffic to a new release before gradually increasing it. Prometheus metrics could help identify increases in errors or response times before the new version receives all production traffic.

The trade-off is that Rolling Deployment is simpler and cheaper, but it does not limit exposure to a bad release as effectively as Canary Deployment. During a rolling update, old and new versions temporarily run together, so some users could experience issues if the new version contains a bug.

## 4. Main Risk

The biggest risk of Rolling Deployment is that the new version may contain a bug while the rollout is still in progress. Since old and new replicas run simultaneously, requests reaching the new version could fail even while the old version continues working.

I would monitor the application's health and error rates to detect this behavior. The `/health` endpoint can help verify that replicas are ready to receive traffic, while `/metrics` and Prometheus can help identify increases in HTTP 500 errors and response times.

If the new version shows unexpected errors, the rollout should be stopped and the previous version restored.
