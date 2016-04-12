module Telegram
  module Bot
    class Api
      ENDPOINTS = %w(
        getMe sendMessage forwardMessage sendPhoto sendAudio sendDocument
        sendSticker sendVideo sendVoice sendLocation sendChatAction
        getUserProfilePhotos getUpdates setWebhook getFile answerInlineQuery
      ).freeze
      REPLY_MARKUP_TYPES = [
        Telegram::Bot::Types::ReplyKeyboardMarkup,
        Telegram::Bot::Types::ReplyKeyboardHide,
        Telegram::Bot::Types::ForceReply,
        Telegram::Bot::Types::InlineKeyboardMarkup
      ].freeze
      INLINE_QUERY_RESULT_TYPES = [
        Telegram::Bot::Types::InlineQueryResultArticle,
        Telegram::Bot::Types::InlineQueryResultGif,
        Telegram::Bot::Types::InlineQueryResultMpeg4Gif,
        Telegram::Bot::Types::InlineQueryResultPhoto,
        Telegram::Bot::Types::InlineQueryResultVideo
      ].freeze

      attr_reader :token

      def initialize(token)
        @token = token
      end

      def method_missing(method_name, *args, &block)
        endpoint = method_name.to_s
        endpoint = camelize(endpoint) if endpoint.include?('_')

        ENDPOINTS.include?(endpoint) ? call(endpoint, *args) : super
      end

      def respond_to_missing?(*args)
        method_name = args[0].to_s
        method_name = camelize(method_name) if method_name.include?('_')

        ENDPOINTS.include?(method_name) || super
      end

      def call(endpoint, raw_params = {})
        params = build_params(raw_params)
        response = http.post("/bot#{token}/#{endpoint}",
                             URI.encode_www_form(params))
        if response.code == '200'
          JSON.parse(response.body)
        else
          fail Exceptions::ResponseError.new(response),
               'Telegram API has returned the error.'
        end
      end

      private

      def build_params(h)
        h.each_with_object({}) do |(key, value), params|
          params[key] = sanitize_value(value)
        end
      end

      def sanitize_value(value)
        jsonify_inline_query_results(jsonify_reply_markup(value))
      end

      def jsonify_reply_markup(value)
        return value unless REPLY_MARKUP_TYPES.include?(value.class)
        arr = value.to_h.map do |key, val|
          val = if val.is_a?(Array)
            Telegram::Bot::Util.deep_array_send(val, :compact_attributes)
          else
            val
          end

          [key, val]
        end

        JSON.generate(Hash[arr])
      end

      def jsonify_inline_query_results(value)
        return value unless value.is_a?(Array) && value.all? { |i| INLINE_QUERY_RESULT_TYPES.include?(i.class) }
        value.map { |i| i.to_h.select { |_, v| v } }.to_json
      end

      def camelize(method_name)
        words = method_name.split('_')
        words.drop(1).map(&:capitalize!)
        words.join
      end

      def http
        @http ||= begin
          uri = URI.parse('https://api.telegram.org')
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          http
        end
      end
    end
  end
end
