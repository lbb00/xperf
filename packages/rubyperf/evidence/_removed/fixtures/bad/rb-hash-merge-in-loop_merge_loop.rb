def tag_jobs(jobs, base)
  jobs.map do |job|
    base.merge("jid" => job.id, "args" => job.args)
  end
end
