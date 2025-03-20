module CustomersHelper
  def customer_status_border_class(customer)
    case customer.status
    when 'Pending' then 'border-l-4 border-yellow-400'
    when 'Contact Established' then 'border-l-4 border-green-400'
    when 'Contact Not Established' then 'border-l-4 border-red-400'
    when 'Unresponsive' then 'border-l-4 border-orange-400'
    when 'Converted' then 'border-l-4 border-blue-400'
    when 'Proposal Sent' then 'border-l-4 border-indigo-400'
    when 'Not Interested' then 'border-l-4 border-gray-400'
    when 'Exhausted' then 'border-l-4 border-purple-400'
    when 'Invalid' then 'border-l-4 border-purple-400'
    else 'border-l-4 border-gray-200'
    end
  end
end
