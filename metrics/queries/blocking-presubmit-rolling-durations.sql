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
    "pr:pull-kubernetes-e2e-gce-100-performance",    
    "pr:pull-kuberentes-bazel-build",    
    "pr:pull-kuberentes-bazel-test",    
    "pr:pull-kuberentes-dependencies",    
    "pr:pull-kuberentes-e2e-gce",    
    "pr:pull-kuberentes-integration",    
    "pr:pull-kuberentes-kubemark-e2e-gce-big",    
    "pr:pull-kuberentes-node-e2e",    
    "pr:pull-kuberentes-typecheck",    
    "pr:pull-kuberentes-verify",    
  )
WINDOW rolling_n_jobs as (
  partition by b.job
  order by b.started
  rows between 10 preceding and current row
)
ORDER BY
  job_name, started
