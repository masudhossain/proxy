Rails.application.routes.draw do

  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  resources :sites
  # get '/' => 'proxy#index'
  get '/proxy' => 'proxy#proxy'
  post '/proxy' => 'proxy#proxy'
  get '/index' => 'proxy#index'

  get '/test' => 'proxy#test'
  # match '*path', to: 'proxy#post', via: :post
  # match '*path', to: 'proxy#get', via: :get
  match '', to: 'sites#show', constraints: lambda { |r| r.subdomain.present? }, :via => [:get]
  match '*path', to: 'sites#show', constraints: lambda { |r| r.subdomain.present? }, :via => [:get]

  match '/' => 'sites#proxy', via: [:get, :post, :put, :patch, :delete]
  match '*path' => 'sites#proxy', via: [:get, :post, :put, :patch, :delete]
end
