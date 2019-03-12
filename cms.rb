require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

before do
  @root = File.expand_path("..", __FILE__)
  @file_list = Dir.glob(@root + "/content_files/*").map do |file|
    File.basename(file)
  end
  p session
  p @file_list
end

get "/" do
  erb :index, layout: :layout
end

def render_html(file_name)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  file = File.read(@file_path)
  markdown.render(file)
end

get "/:file_name" do
  @file_name = params[:file_name]
  @file_path = @root + "/content_files/" + @file_name
  # if !@file_list.include?(@file_name)
  if File.file?(@file_path) == false
    session[:error] = "#{@file_name} does not exist"
    redirect "/"
  else
    if File.extname("#{@file_path}") == ".md" || File.extname("#{@file_path}") == ".mkd"
      headers["Content_type"] = "text/html"
      render_html(@file_name)
    else
      headers["Content-Type"] = "text/plain"
      File.read("content_files/#{@file_name}")
    end
  end
end
