#standardSQL
/*
  For all jobs in release-master-blocking
    from all runs in the last week
    a row for each job that started and finished
    with a rolling average and stddev from the last N=10 rows

  Different series are going to have data points at different
  times. Google Sheets and Data Studio don't play well with this.
*/
SELECT
  timestamp_trunc(b.started, day) start_day,
  b.started started,
  b.job job_name,
  round(b.elapsed / 60.0, 3) duration,
  b.tests_run tests_run,
  b.tests_failed tests_failed,
  b.passed passed,
  round(avg(b.elapsed / 60.0) over rolling_n_jobs, 3) as duration_rollavg,
  round(stddev_pop(b.elapsed / 60.0) over rolling_n_jobs, 3) as duration_rolldev
FROM
  `k8s-gubernator.build.week` AS b
WHERE
  b.elapsed IS NOT NULL AND
  b.job IN (
    "ci-kubernetes-bazel-build",    
    "ci-kubernetes-bazel-test",
    "ci-kubernetes-build",
    "ci-kubernetes-build-fast",
    "ci-kubernetes-e2e-gci-gce-alpha-features",    
    "ci-kubernetes-e2e-gci-gce",    
    "ci-kubernetes-e2e-gci-gce-ingress",    
    "ci-kubernetes-e2e-gci-gce-scalability",
    "ci-kubernetes-e2e-gci-gce-serial",
    "ci-kubernetes-e2e-gci-gce-slow",
    "ci-kubernetes-e2e-gce-device-plugin-gpu",
    /* TODO(spiffxp): these are outliers and should be in release-informing
    "ci-kubernetes-e2e-gce-scale-correctness",
    "ci-kubernetes-e2e-gce-scale-performance",
    */
    "ci-kubernetes-integration-master",
    "ci-node-kubelet",
    "ci-kuberentes-verify-master"
  )
WINDOW rolling_n_jobs as (
  partition by b.job
  order by b.started
  rows between 10 preceding and current row
)
ORDER BY
  job_name, started
