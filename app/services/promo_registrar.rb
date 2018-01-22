# Registers each verified channel for a publisher
class PromoRegistrar < BaseApiClient
  include PromosHelper

  def initialize(publisher:, promo_id: active_promo_id)
    @publisher = publisher
    @promo_id = promo_id
  end

  def perform
    channels = @publisher.channels.where(verified: true)

    return perform_later if channels.count > 5

    channels.each do |channel|
      if should_register_channel?(channel)
        referral_code = register_channel(channel)
        promo_registration = PromoRegistration.new(channel_id: channel.id, promo_id: @promo_id, referral_code: referral_code)
        promo_registration.save!
      end
    end
  end

  def register_channel(channel)
    return register_channel_offline if perform_promo_offline?
    response = connection.put do |request|
      request.headers["Authorization"] = api_authorization_header
      request.headers["Content-Type"] = "application/json"
      request.body = 
          {
            "promo": "#{@promo_id}",
            "publisher": "#{channel.details.youtube_channel_id}", # TO DO: create single method that selects the brave_publisher_id OR youtube_channel_id 
            "name": "#{channel.publication_title}"
          }.compact.to_json
      request.url("/api/1/promo/publishers")
    end
    referral_code = JSON.parse(response.body)["referral_code"]
    referral_code

    # TO DO: if promo server returns a duplicate error, use the PromoRegistrationGetter to get/set it.
    # TO DO: handle other errors
  end

  def register_channel_offline
    Rails.logger.info("PromoRegistrar #register_channel offline.")
    offline_referral_code
  end

  private

  def api_base_uri
    Rails.application.secrets[:api_promo_base_uri]
  end

  def api_authorization_header
    "Bearer #{Rails.application.secrets[:api_promo_key]}"
  end

  # Register channel if it hasn't been registered, or if registration doesn't have referral code
  def should_register_channel?(channel)
    if channel.promo_registration.blank?
      return true
    elsif channel.promo_registration.referral_code.blank?
      return true
    else
      false
    end
  end
end