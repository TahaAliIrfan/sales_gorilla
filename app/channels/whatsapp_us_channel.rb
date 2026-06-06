# Real-time WhatsApp US stream.
#
# Mobile/web clients subscribe to receive new messages without polling.
#
# Two streams are wired up per subscription:
#   - whatsapp_us:user:<user_id>           — every new message touching a
#                                            customer the user can see (good for
#                                            the conversations list view).
#   - whatsapp_us:customer:<customer_id>   — every new message for the specific
#                                            customer the client is viewing
#                                            (only added if `customer_id` is
#                                            passed at subscribe time).
#
# Auth: see ApplicationCable::Connection — clients must present a valid JWT
# via the `?token=` query param when opening the WebSocket.
#
# Broadcast: see WhatsappUsBroadcaster, called from the inbound webhook and
# from the outbound send paths (web + API) so devices stay in sync regardless
# of which surface created the message.
class WhatsappUsChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_user

    stream_from user_stream(current_user.id)

    if params[:customer_id].present?
      customer = find_accessible_customer(params[:customer_id])
      return reject unless customer

      stream_from customer_stream(customer.id)
    end
  end

  def unsubscribed
    stop_all_streams
  end

  class << self
    def user_stream(user_id)
      "whatsapp_us:user:#{user_id}"
    end

    def customer_stream(customer_id)
      "whatsapp_us:customer:#{customer_id}"
    end
  end

  # Instance access to the same names so #subscribed can use them.
  def user_stream(user_id);    self.class.user_stream(user_id);    end
  def customer_stream(cid);    self.class.customer_stream(cid);    end

  private

  # Same role gates as Api::V2::WhatsappController#accessible_customers.
  def find_accessible_customer(id)
    scope =
      case current_user.highest_role&.key
      when 'admin'   then Customer.all
      when 'manager' then Customer.where(user_id: [current_user.id] + current_user.associates.pluck(:id))
      else                current_user.customers
      end
    scope.find_by(id: id)
  rescue StandardError
    nil
  end
end
