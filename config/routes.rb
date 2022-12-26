Rails.application.routes.draw do

  get '/' => 'proxy#index'
  get '/proxy' => 'proxy#proxy'
  post '/proxy' => 'proxy#proxy'
  get '/index' => 'proxy#index'

  get '/test' => 'proxy#test'
  # match '*path', to: 'proxy#post', via: :post
end
