require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../content_files", __FILE__)
  end
end

def data_path_archives
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/archives", __FILE__)
  else
    File.expand_path("../archives", __FILE__)
  end
end

def inspect_rack_env
  puts "\n\n"
  puts "inspect env:"
  env.each do |key, value|
    p "#{key} => #{value}"
  end
  puts "\n\n"
end

def inspect_session_data
  puts "\n\n"
  puts "inspect session:"
  session.each do |key, value|
    p "#{key} => #{value}"
  end
  puts "\n\n"
end

def inspect_file_list
  p @file_list
end

def require_signed_in_user
  unless session[:username]
    session[:flash] = "You must be signed in to do that!"
    redirect "/sign-in"
  end
end

def get_users_file
  if ENV["RACK_ENV"] == "test"
    path = File.join(data_path, "test_users.yaml")
  else
    path = "users.yaml"
  end
    YAML.load(File.read(path))
end

before do
  pattern = File.join(data_path, "*")
  @file_list = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  # inspect_rack_env
  # inspect_session_data
  # inspect_file_list

  @users = get_users_file
  p @users
end

get "/" do
  erb :enter, layout: :layout
end

get "/sign-in" do
  erb :sign_in, layout: :layout
end

def valid_user?(username, password)
  if @users.key?(username)
    bcrypt_password = BCrypt::Password.new(@users[username])
    bcrypt_password == password
  else
    false
  end
end

post "/verify-sign-in" do
  username = params[:username]
  password = params[:password]
  if valid_user?(username, password)
    session[:username] = username
    session[:flash] = "You have successfully signed in!"
    redirect "/index"
  else
    session[:flash] = "Sorry, but your username and password are not correct."
    status 422
    erb :sign_in, layout: :layout
  end
end

get "/sign-up" do
  erb :sign_up, layout: :layout
end

def signup_error(username, password)
  if username.length == 0 || username.length > 25
    "Username must be between 1 and 25 characters!"
  elsif password.length < 3 || password.length > 25
    "Password must be between 3 and 25 characters!"
  elsif !password.match /[!@#$%^&*()?]/
    "Password must contain at least one letter, one number and one special character."
  end
end

post "/verify-sign-up" do
  username = params[:username]
  password = params[:password]

  error = signup_error(username, password)

  if error
    session[:flash] = error
    erb :sign_up, layout: :layout
  else
    @users[username] = BCrypt::Password.create(password)
    File.open("users.yaml", "w") { |file| file.write(@users.to_yaml) }
    session[:username] = username
    redirect "/index"
  end
end

post "/sign-out" do
  session.delete(:username)
  session[:flash] = "You have signed out."
  redirect "/"
end

# access index page
get "/index" do
  erb :index, layout: :layout
end

def render_html(file_path)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  file = File.read(file_path)
  markdown.render(file)
end

def get_content(file_path)
  file_extension = File.extname("#{file_path}")
  case file_extension
  when /.[(mkd)(md)]/
    {headers: "text/html;charset=utf-8", content: render_html(file_path)}
  when ".txt"
    {headers: "text/plain", content: File.read(file_path)}
  end
end

# view content for a document
get "/:file_name" do
  require_signed_in_user

  @file_name = params[:file_name]
  @file_path = File.join(data_path, @file_name)
  if File.file?(@file_path) == false
    session[:flash] = "#{@file_name} does not exist"
    redirect "/index"
  else
    headers["Content-Type"] = get_content(@file_path)[:headers]
    get_content(@file_path)[:content]
  end

end

# edit content for a document
get "/:file_name/edit" do
  require_signed_in_user

  @file_name = params[:file_name]
  @file_path = File.join(data_path, @file_name)
  @content = get_content(@file_path)[:content]
  erb :edit_file, layout: :layout
end

def rename_old_version(file_name)
  basename = File.basename(file_name, ".*")
  ext = File.extname(file_name)
  archives = Dir.glob("archives/*").select do |file|
    file.include?(basename)
  end
  idx = archives.length + 1
  File.join(data_path_archives, (basename + "_" + idx.to_s + ext))
end


# submit changes to a document and archive old copy
post "/index/:file_name"  do
  require_signed_in_user
  file_name = params[:file_name]
  file_path = File.join(data_path, file_name)
  File.rename(file_path, rename_old_version(file_name))
  File.write(file_path, params[:document_content])
  session[:flash] = "#{file_name} successfully updated. Previous versions preserved in archives."
  redirect "/index"
end

# create a new document name
get "/index/new" do
  require_signed_in_user

  erb :new, layout: :layout
end

def name_error(name)
  # if !name.match /\w+\.[a-z]{2,3}$/
  if !name.match /\w+\.[(txt)(mkd)(md)]/
    "Name must be between 0 and 100 characters and end with a valid file extension"
  elsif @file_list.include?(name)
    "Name must be unique"
  elsif name.include?(' ')
    "Name may not include spaces"
  end
end

# submit a new name and add new file to data
post "/index" do
require_signed_in_user

  file_name = params[:file_name].strip
  error = name_error(file_name)
  if error
    session[:flash] = error
    erb :new, layout: :layout
  else
    File.new(File.join(data_path, file_name), "w+")
    session[:flash] = "#{file_name} created"
    redirect "/index"
  end
end

# delete a file
post "/index/:file_name/delete" do
  require_signed_in_user

  file_name = params[:file_name]
  file_path = File.join(data_path, file_name)
  File.delete(file_path)
  session[:flash] = "#{file_name} deleted"
  redirect "/index"
end

# duplicate a file
post "/index/:file_name/duplicate" do
  file_name = params[:file_name]
  file_path = File.join(data_path, file_name)
  content = get_content(file_path)[:content]
  File.open(File.join(data_path, "dup_#{file_name}"), "w") { |file| file.write(content) }
  session[:flash] = "#{file_name} duplicated"
  redirect "/index"
end

# see archives

get "/index/archives" do
  @archives = Dir.glob("archives/*.*").map { |f| File.basename(f) }.sort
  erb :archives, layout: :layout
end

get "/index/archives/:file_name" do
  @file_name = params[:file_name]
  @file_path = File.join(data_path_archives, @file_name)
  p @file_path
  if File.file?(@file_path) == false
    session[:flash] = "#{@file_name} does not exist"
    redirect "/index/archives"
  else
    headers["Content-Type"] = get_content(@file_path)[:headers]
    get_content(@file_path)[:content]
  end

end
