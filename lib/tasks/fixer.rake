namespace :fixer do

  desc "check fixer status mismatches"
  task check: [:environment] do

    puts "Finding all tasks with status mismatch..."
    mismatched_tasks = Task.get_mismatched_status('working')
    mismatched_tasks.each do |task|
      puts "Task #{task.owner_type}:#{task.id} has status '#{task.status}' with results: " + task.results.inspect

    end

  end

end
    
