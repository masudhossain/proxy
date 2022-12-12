Rails.application.routes.draw do

  get '/' => 'proxy#index'
  get '/proxy' => 'proxy#proxy'
  post '/proxy' => 'proxy#proxy'
  get '/index' => 'proxy#index'
end
