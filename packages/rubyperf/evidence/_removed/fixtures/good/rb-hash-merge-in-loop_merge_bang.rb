# Prefer build-once (literal / assign). Blind dup+merge! is slower than merge.
def tag_jobs(jobs, base)
  jobs.map do |job|
    {
      "queue" => base["queue"],
      "retry" => base["retry"],
      "class" => base["class"],
      "jid" => job.id,
      "args" => job.args
    }
  end
end
