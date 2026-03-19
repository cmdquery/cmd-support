class Integrations::Slack::SendPendingAlertService
  pattr_initialize [:conversation!, :hook!]

  def perform
    return unless conversation.open?
    return if hook.reference_id.blank?
    return if conversation.identifier.present?

    response = slack_client.chat_postMessage(
      channel: hook.reference_id,
      text: alert_text
    )
    conversation.update!(identifier: response['ts'])
  rescue Slack::Web::Api::Errors::IsArchived, Slack::Web::Api::Errors::AccountInactive, Slack::Web::Api::Errors::MissingScope,
         Slack::Web::Api::Errors::InvalidAuth,
         Slack::Web::Api::Errors::ChannelNotFound, Slack::Web::Api::Errors::NotInChannel => e
    Rails.logger.error e
    hook.prompt_reauthorization!
    hook.disable
  end

  private

  def alert_text
    "<!subteam^S0AMP9N98CW> *Handover to human needed*\n" \
      "*Inbox:* #{conversation.inbox.name}\n" \
      "*Contact:* #{conversation.contact.name}\n" \
      "<#{conversation_url}|View conversation>"
  end

  def conversation_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{conversation.account_id}/conversations/#{conversation.display_id}"
  end

  def slack_client
    @slack_client ||= Slack::Web::Client.new(token: hook.access_token)
  end
end
