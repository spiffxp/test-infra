#standardSQL
/*
  I think this is now showing me 99, 90, 75, 50 percentiles
  for each test, for each job,
  so I can see the worst tests,
  and which jobs they're the worst in

  in this example we're looking at tests that are _not_ tagged [Slow]
  but _are_ taking longer than 5 minutes (our definition of [Slow] according to docs in k/community)
*/
select
  test_name,
  job_name,
  runs,
  round(1 - (failed_runs/runs), 2) pass_rate,
  p50_time,
  p75_time,
  p99_time,
  round(p99_time - p50_time, 3) as delta_p99_p50
from (
  select
    test_name,
    job_name,
    count(*) as runs,
    countif(test_failed) as failed_runs,
    round(max(_p99_time),3) as p99_time,
    round(max(_p90_time),3) as p90_time,
    round(max(_p75_time),3) as p75_time,
    round(max(_p50_time),3) as p50_time
  from (
    select
      b.job as job_name,
      t.name as test_name,
      if(t.failed = true, true, false) test_failed,
      percentile_cont(t.time, 0.99) over(partition by t.name, b.job) as _p99_time,
      percentile_cont(t.time, 0.90) over(partition by t.name, b.job) as _p90_time,
      percentile_cont(t.time, 0.75) over(partition by t.name, b.job) as _p75_time,
      percentile_cont(t.time, 0.50) over(partition by t.name, b.job) as _p50_time
    from 
      `k8s-gubernator.build.week` as b
    cross join 
      unnest(test) as t
    where
      regexp_contains(b.job, 'kubernetes-e2e')
      /*
        why exclude these jobs:
        - the upgrade/downgrade jobs are just not worth the noise right now
        - the eks/gke jobs are similarly noisy
        - stable3|stable2 jobs contain tests that have since been tagged or modified
        - stable1 is currently old enough that it's in the same position
        - the pr job can run against older branches, only interested in current / fixable tests
      */
      and not regexp_contains(b.job, 'upgrade|downgrade|aws-eks|gke-cos|gke-ubuntu|gke-canary|stable3|stable2|stable1|pr:pull-kubernetes-e2e-gce')
      /* 
        ignore some of the longer fake/meta tests for now;
        maybe later it'd be neat to know how long up/down take
      */
      and t.name not in (
        'Test',
        'Timeout',
        'Up',
        'Deferred TearDown',
        'TearDown',
        'DumpClusterLogs',
        'DumpClusterLogs (--up failed)',
        'Extract',
        'IsUp',
        'TearDown Previous',
        'Check APIReachability',
        'BeforeSuite',
        'UpgradeTest',
        'SkewTest',
        'Node Tests'
       )
  )
  where
    not regexp_contains(test_name, r"\[Slow\]")
    and _p75_time > 300.0
  group by
    test_name , job_name
  order by
    p50_time desc
)
order by
  p50_time desc
