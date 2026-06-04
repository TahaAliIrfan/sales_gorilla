Calling::Engine.routes.draw do
  # Browser-based phone interface (mounted at /calling in the host).
  root to: "calling#index"

  get   "/token",              to: "calling#token",              as: :token
  match "/voice",              to: "calling#voice",              via: %i[get post], as: :voice
  get   "/available_numbers",  to: "calling#available_numbers",  as: :available_numbers
  post  "/store_customer_id",  to: "calling#store_customer_id",  as: :store_customer_id
  post  "/recording_status",   to: "calling#recording_status",   as: :recording_status
end
