require "sinatra/base"
require "sinatra/content_for"
require "sinatra/cookies"
require "securerandom"
require "active_support"
require "active_support/core_ext/object/blank"

require_relative "./helpers"
require_relative "./awawawa"
require_relative "./signage"

if ENV["SEND_REAL_EMAILS"]
  require_relative "./loops"
end

class ShipmentViewer < Sinatra::Base
  helpers Sinatra::ContentFor
  helpers Sinatra::Cookies
  helpers Sinatra::RenderMarkdownHelper
  helpers Sinatra::SchmoneyHelper
  helpers Sinatra::IIHelper

  set :host_authorization, permitted_hosts: []

  def footer_commit
    @footer_commit ||= if ENV["SOURCE_COMMIT"]
        "rev #{ENV["SOURCE_COMMIT"][...7]}"
      else
        "development!"
      end
  end

  def gen_url(email)
    "#{ENV["BASE_URL"]}/dyn/shipments/#{email}?signature=#{sign(email)}"
  end

  def mail_out_link(email)
    link = gen_url email
    if ENV["SEND_REAL_EMAILS"]
      raise "no transactional_id?" unless ENV["TRANSACTIONAL_ID"]
      loops_send_transactional(email, ENV["TRANSACTIONAL_ID"], { link: })
    else
      puts "[EMAIL] to: #{email}, link: #{link}"
    end
  end

  def bounce_to_index!(message)
    @error = message
    halt erb :index
  end

  def external_link(text, href)
    "<a target='_blank' href='#{href}'>#{text} <i class='fa-solid fa-arrow-up-right-from-square'></i></a>"
  end

  set :sessions, true

  get "/*" do
    redirect to("https://mail.hackclub.com/")
  end

  get "/dyn/jason/:email" do
    content_type :json
    bounce_to_index! "just what are you trying to pull?" unless params[:signature] && sig_checks_out?(params[:email], params[:signature])

    @show_ids = !!params[:ids]

    @shipments = get_shipments_for_user params[:email]

    @shipments.to_json
  end

  post "/api/presign" do
    request.body.rewind
    key = request.env["HTTP_AUTHORIZATION"]
    unless key && ENV["PRESIGNING_KEYS"]&.split(",").include?(key)
      bounce_to_index! "not the right key ya goof"
    end
    email = request.body.read
    puts "#{key.split("@").last} is presigning a link for #{email}..."
    gen_url email
  end
end
