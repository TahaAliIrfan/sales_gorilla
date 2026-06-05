module TasksHelper
  # Maps a task's derived state to a relay pill modifier class + label. Mirrors
  # the legacy coloured status badges (completed/overdue/due today/pending/in
  # progress/cancelled) using the DS rl-pill tones.
  def relay_task_state_pill(task)
    if task.completed?
      { klass: "rl-pill--success", label: "Completed" }
    elsif task.overdue?
      { klass: "rl-pill--danger", label: "Overdue" }
    elsif task.due_today? && task.pending?
      { klass: "rl-pill--info", label: "Due today" }
    elsif task.pending?
      { klass: "rl-pill--warning", label: "Pending" }
    elsif task.in_progress?
      { klass: "rl-pill--brand", label: "In progress" }
    elsif task.cancelled?
      { klass: "rl-pill", label: "Cancelled" }
    else
      { klass: "rl-pill", label: task.status_display }
    end
  end
end
