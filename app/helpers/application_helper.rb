module ApplicationHelper
  def format_activity_action(action)
    case action
    when 'created' then 'Deal Created'
    when 'updated' then 'Deal Updated'
    when 'stage_changed' then 'Stage Changed'
    when 'user_assigned' then 'User Assigned'
    when 'marked_won' then 'Marked as Won'
    when 'marked_lost' then 'Marked as Lost'
    when 'deleted' then 'Deal Deleted'
    else action.humanize
    end
  end
  
  def activity_color_class(action)
    case action
    when 'created' then 'bg-blue-500'
    when 'updated' then 'bg-yellow-500'
    when 'stage_changed' then 'bg-purple-500'
    when 'user_assigned' then 'bg-indigo-500'
    when 'marked_won' then 'bg-green-500'
    when 'marked_lost' then 'bg-red-500'
    when 'deleted' then 'bg-gray-500'
    else 'bg-gray-400'
    end
  end

  def sortable(column, title = nil)
    title ||= column.titleize
    direction = (column == params[:sort] && params[:direction] == "asc") ? "desc" : "asc"
    icon = column == params[:sort] ? (params[:direction] == "asc" ? "↑" : "↓") : ""
    
    link_to "#{title} #{icon}".html_safe, 
            { sort: column, direction: direction, search: params[:search], user_id: params[:user_id] },
            class: "hover:text-gray-900"
  end
  
  # Determine country label based on phone number prefix
  def get_country_label(phone_number)
    case phone_number
    when /^\+1/ 
      "US Number"
    when /^\+44/
      "UK Number"
    when /^\+61/
      "AUS Number"
    else
      "Other Number"
    end
  end
  
  # Helper for complexity color classes in cost estimates
  def complexity_color(complexity)
    case complexity&.downcase
    when 'low'
      'bg-green-100 text-green-800'
    when 'high'
      'bg-red-100 text-red-800'
    when 'medium'
    else
      'bg-yellow-100 text-yellow-800'
    end
  end
end
