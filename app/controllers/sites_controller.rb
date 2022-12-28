class SitesController < ApplicationController
  before_action :set_site, only: [:show, :proxy]

  # GET /sites or /sites.json
  def index
    # parse the website url to get the domain and protocol only
    require 'uri'
    url = params[:website]
    @uri = URI(url)
    @domain = "#{@uri.scheme}://#{@uri.host}"
    @path = @uri.path 

    @site = Site.find_or_create_by(website: @domain)


    render json: {
      success: true, 
      site: {
        website: @site.website,
        token: @site.token,
        domain: @domain,
        path: @path, 
        iframe: Rails.env.development? ? "https://#{@site.token}.queue.ngrok.io#{@path}" : "https://#{@site.token}.proxysite.usequeue.com#{@path}"
      } 
    }
  end

  # GET /sites/1 or /sites/1.json
  def show
    if params[:format].blank? 
      # DIDNT WORK IN PROD
      # site_url =  request.env["REQUEST_URI"][0..request.env["REQUEST_URI"].index("/proxy")-1] # prefix i.e. "http://localhost:3000"
      
      if Rails.env.development?
        site_url = "https://#{@site.token}.queue.ngrok.io"
      else
        site_url = "http://#{@site.token}.proxysite.usequeue.com"
      end
          
      # INSERT START

      if params[:formlnk]
        @url = params[:formlnk]
      else
        # @url = URI.unescape(request.env["QUERY_STRING"][4..request.env["QUERY_STRING"].length])  #Full URL from querystring url= "http://..."
        @url = params[:path].blank? ? @domain : "#{@domain}/#{params[:path]}"
        # @url = @domain
      end
      method = request.env["REQUEST_METHOD"]
      data   = request.env["RAW_POST_DATA"] #if empty add the actual querystring to data
      port   = 80               
                          
      # Prepend http/https protocol if not present
      if @url.index('http://') == nil and @url.index('https://') == nil
        @url = 'http://' + @url
      end

      # @baseurl i.e. http://example.com/
      # @xurl i.e. http://example.com/subsirectory/
      @uri = URI.parse(@url)
      @baseurl = @uri.scheme + '://' + @uri.host 

      if @url.length == @baseurl.length
        @xurl = @url
      else
        iOffset = @url.rindex('/')
        @xurl = @url[0..iOffset]
      end
      if @xurl[-1,1] != "/"
        @xurl=@xurl + "/"
      end
      # if @baseurl[-1,1] != "/"
      #   @baseurl=@baseurl + "/"
      # end

      # determines querystring i.e. http://example.com/subsirectory?data=this_stuff
      iOffset = @url.rindex('?')
      if iOffset != nil
        @geturl = @url[0..iOffset-1] #url including page i.e. http://example.com/subsirectory/test.html less the querystring
        @query = @url[iOffset+1..@url.length] #querystring
        path = "/" + @url[@xurl.length..iOffset-1] rescue "/" #only the page i.e. /test.html
      else
        @geturl = @url
        @query = "" #querystring
        path = "/" + @url[@xurl.length..@url.length]  rescue "/"         
      end

      host = @uri.host #only domain


      a = Mechanize.new { |agent|
        # agent.request_headers = get_request_headers(request)
        agent.user_agent_alias = 'Mac Safari' #TODO pass user's browser type
        # User Agent aliases
          # AGENT_ALIASES = {
          #   'Windows IE 6' => 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)',
          #   'Windows IE 7' => 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322; .NET CLR 2.0.50727)',
          #   'Windows Mozilla' => 'Mozilla/5.0 (Windows; U; Windows NT 5.0; en-US; rv:1.4b) Gecko/20030516 Mozilla Firebird/0.6',
          #   'Mac Safari' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_2; de-at) AppleWebKit/531.21.8 (KHTML, like Gecko) Version/4.0.4 Safari/531.21.10',
          #   'Mac FireFox' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.6; en-US; rv:1.9.2) Gecko/20100115 Firefox/3.6',
          #   'Mac Mozilla' => 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.4a) Gecko/20030401',
          #   'Linux Mozilla' => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.4) Gecko/20030624',
          #   'Linux Firefox' => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.2.1) Gecko/20100122 firefox/3.6.1',
          #   'Linux Konqueror' => 'Mozilla/5.0 (compatible; Konqueror/3; Linux)',
          #   'iPhone' => 'Mozilla/5.0 (iPhone; U; CPU like Mac OS X; en) AppleWebKit/420+ (KHTML, like Gecko) Version/3.0 Mobile/1C28 Safari/419.3',
          #   'Mechanize' => "WWW-Mechanize/#{VERSION} (http://rubyforge.org/projects/mechanize/)"
          # }
      }

      # Setup Cookie Jar
      #works from file
      # a.cookie_jar.load("mycookies.txt", format = :yaml) rescue ""

      require 'yaml'
      begin
        if !session[:mycookies].nil? and session[:mycookies].length < 4000
          a.cookie_jar = YAML.load(session[:mycookies]) 
        else
          a.cookie_jar.clear
        end
      rescue
      end

      # Page request from form
      if params[:verb]
        
        if params[:verb] == 'get' 
          # puts params
          # puts @url
          
          #Add a question mark to the end of the base url if one does not exist
          if @url.index('?') == nil
            @url << '?'
          end

          #Build params query string
          params.each do |k, v|
            if k != 'lnk' and k != 'verb'
              @url << "&#{k}=#{v}"
            end
          end
          
          begin
            a.get(@url) do |page|
              @rawdoc =  page.body 
              # response.headers= page.headers
            end
            
          rescue
            a.cookie_jar.clear
            a.get(@url) do |page|
              @rawdoc =  page.body 
            end
          end
          
        else #POST
          
          # page = browser.post('http://www.mysite.com/login', {
          #   "email" => "myemail%40gmail.com",
          #   "password" => "something",
          #   "remember" => "1",
          #   "loginSubmit" => "Login",
          #   "url" => ""
          # })
          
            #THERE HAS GOT TO BE A BETTER WAY TO FORMAT PARAMS FOR MECHANIZE POST
            paramsstring = ""
            s = params.to_query
            paramsarray = s.split('&')
            paramsarray.each do |element|
              elementarray = element.split('=')
                if  !elementarray[1].nil?
                  paramsstring << '"' + elementarray[0] + '" => "' +  URI.unescape(elementarray[1]) + '", '
                end
            end
            
            #Fix Amazon logins
            if @url.index('https://www.amazon.com/ap/sign-in')
              paramsstring << '"useRedirectOnSuccess" => "1", '
              paramsstring << '"protocol" => "https", '
              paramsstring << '"referer" => "flex", '
              paramsstring << '"sessionId" => "' + params[:sessionId] + '", '
              paramsstring << '"password" => "' + params[:password] + '", '
              paramsstring << '"email" => "' + params[:email] + '", '
              paramsstring << '"query" => "flex", '
              paramsstring << '"metadata2" => "unknown", '
              paramsstring << '"metadata3" => "unknown", '
              paramsstring << '"action" => "sign-in", '
              
              # paramlist = '-d "disableCorpSignUp=&x=152&y=11&mode=&useRedirectOnSuccess=1&protocol=https&referer=flex&path=/gp/yourstore&sessionId=' + params[:sessionId] + '&password=' + params[:password] + '&pageAction=/gp/yourstore&redirectProtocol=&metadataf1=&metadata2=unknown&metadata3=unknown&action=sign-in&email=' + params[:email] + '&query=signIn=1&ref_=pd_irl_gw' + '"'
              # curlverb = ''
            end
            
            
                      
            # TEST = http://www.cs.unc.edu/~jbs/resources/perl/perl-cgi/programs/form1-POST.html

            begin 
              page = a.post(@url, params)
              @rawdoc = page.body
              
            end 
          

        end
            
      else
        begin
          a.get(@url) do |page| 
            @rawdoc =  page.body 
          end    
        rescue
          begin
            # a.cookie_jar.clear
            a.get(@url) do |page| 
              @rawdoc =  page.body 
            end    
          rescue =>e
            @rawdoc = e.page.body
            puts "===>errpr"
            puts e.page.header
          end
        end

      end
          
      #works to file
      # a.cookie_jar.save_as("mycookies.txt", format = :yaml )

      session[:mycookies] = a.cookie_jar.to_yaml rescue ""

      # FORMAT HTML CONTENT 
      @doc = Nokogiri::HTML(@rawdoc)

      # MANIPULATE HTML CONTENT A AND AREA LINKS TO PASS BACK THROUGH PROXY 
      @doc.xpath('//a|//area').each { |a|
        #regular link found
        if a['href'] != nil and a['href'][0..0] != "#" # dont process for anchor tags
          if a['href'].index('http://') == nil and a['href'].index('https://') == nil
            if a['href'] == "/"
              link = @baseurl
            else
              if @baseurl[@baseurl.length..@baseurl.length] == '/' or a['href'][0..0] == "/"
                link = @baseurl + a['href']
              else
                link = @baseurl + '/' + a['href']
              end
            end
          else
            link = a['href']                
          end

          link.gsub!("http:///", @baseurl) #added to test localhost entries

          #not anchor 
          if a['href'] != nil and a['href'] != "#"
            # check if the url is within the website or an external one. 
            if a['href'].include?(@baseurl)  
              link = site_url + URI.escape(link.gsub!(@baseurl, "").strip)
              a['href'] = link
            end
          end
        end
      }

      # MANIPULATE HTML CONTENT IMAGES, SCRIPTS, AND IFRAMES TO USE ACTUAL LINKS INCLUDING RELATIVE LINKS
      @doc.xpath('//img|//script|//iframe|//embed').each { |a|
          if a['src'] != nil

            if a['src'].index('http://') == nil and a['src'].index('https://') == nil
              if a['src'] == "/"
                link = @baseurl
              else
                if @baseurl[@baseurl.length..@baseurl.length] == '/' or a['src'][0..0] == "/"
                  if a['src'].start_with?("//") 
                    link = a['src']
                  else
                    link = @baseurl + a['src']
                  end
                else
                  link = @baseurl + '/' + a['src']
                end
              end
            else
              link = a['src']
            end

            link.gsub!("http:///", @baseurl) #added to test localhost entries

            if a['src'] != nil and a['src'] != "#"
              link = link.strip
              # puts link 
              # puts a['element']
              # if a['element'] == "script"
                # link = site_url + '?lnk=' + URI.escape(link.strip)
                # a['src'] = link
              # else
                # a['src'] = link
              # end 

              # check if the url is within the website or an external one. 
              if link.include?(@baseurl)
                link = site_url + URI.escape(link.gsub!(@baseurl, "").strip)
                a['src'] = link
              else 
                a['src'] = link
              end
            end
          end
      }

      # MANIPULATE HTML CONTENT IMAGES TO USE ACTUAL LINKS INCLUDING RELATIVE LINKS
      @doc.xpath('//link').each { |a|
        if a['href'] != nil
          if a['href'].index('http://') == nil and a['href'].index('https://') == nil
            if a['href'] == "/"
              link = @baseurl
            else
              if (@baseurl[@baseurl.length..@baseurl.length] == '/' or a['href'][0..0] == "/") 
                if a['href'].start_with?("//")
                  link = a['href'] 
                else
                  link = @baseurl + a['href']
                end
              else 
                link = @baseurl + '/' + a['href']
              end
            end
          else
            link = a['href']
          end

          link.gsub!("http:///", @baseurl) #added to test localhost entries

          link = link.strip
          # link = site_url + '?lnk=' + URI.escape(link.strip)
          # a['href'] = link

          # check if the url is within the website or an external one. 
          if link.include?(@baseurl)
            link = site_url + URI.escape(link.gsub!(@baseurl, "").strip)
            a['href'] = link
          else 
            a['href'] = link
          end
        end
      }

      # MANIPULATE HTML CONTENT IMAGES TO USE ACTUAL LINKS INCLUDING RELATIVE LINKS
      @doc.xpath('//form').each { |a|

        if a['action'] != nil
          
          if a['action'].index('http://') == nil and a['action'].index('https://') == nil
            if a['action'] == "/"
              link = @baseurl
            else
              if @baseurl[@baseurl.length..@baseurl.length] == '/' or a['action'][0..0] == "/"
                link = @baseurl + a['action']
              else
                link = @baseurl + '/' + a['action']
              end
            end
          else
            link = a['action']
          end
          
          method = a['method']
          if !method
            method = "get"
          end
          method.downcase

          link.gsub!("http:///", @baseurl) #added to test localhost entries

          if a['action'] != nil and a['action'] != "#"
            
            formaction = link.strip
            link = site_url + '?url=' + URI.escape(link.strip)

            a['action'] = link     

            # Add hidden input text form with url
            lnk_node = Nokogiri::XML::Node.new('input', a)
            lnk_node['type'] = 'hidden'
            lnk_node['name'] = 'formlnk'
            lnk_node['value'] = URI.escape(formaction.strip)
            a.add_child(lnk_node)

            # Add hidden input text form with verb
            lnk_node = Nokogiri::XML::Node.new('input', a)
            lnk_node['type'] = 'hidden'
            lnk_node['name'] = 'verb'
            lnk_node['value'] = method
            a.add_child(lnk_node)

          end
        end
      }

      ##FINAL MISC CLEANUP
      @finaldoc = @doc.to_s 
          
      # #Check for any links that may be hiding in javascripts
      # @finaldoc = @finaldoc.gsub(/href="\/\//, 'href="https://')
      # @finaldoc.gsub(/href="\/(?!\/)/, 'href="' + site_url + "?url=" + @baseurl + "/")
      # @finaldoc.gsub("href='/", "href='" + site_url + "?url=" + @baseurl + "/")
      # 
      # #prepend baseurl on src tags in javascript
      # @finaldoc = @finaldoc.gsub(/src="\/\//, 'src="https://')
      # @finaldoc = @finaldoc.gsub(/src="\/(?!\/)/, 'src="' + @baseurl + '/')
      # @finaldoc = @finaldoc.gsub('src="/', 'src="' + @baseurl + '/' ) 
      # 
      # #Why does Amazon care about Firefox browsers?
      @finaldoc = @finaldoc.gsub('Firefox', 'FirefoxWTF' ) 

      # FIX JAVASCRIPT RELEATIVE URLS
      # @finaldoc = @finaldoc.gsub("script('/", "script('" + @baseurl + '/')

      # @finaldoc = @finaldoc.gsub("'/", "'" + @baseurl + '/')

      # #Hack to remove double wacks in URL ie http://sunsounds.org//audio//programs
      # @finaldoc.gsub!("://", "/::")
      # @finaldoc.gsub!("//", "/")
      # @finaldoc.gsub!("/::", "://")         

      #Add baseURL to code within embedded styles
      # @finaldoc = @finaldoc.gsub("url(/", "url(" + @baseurl + '/')  

      #Remove frame breaking javascript
      @finaldoc = @finaldoc.gsub(".location.replace", "") 

      #Remove special characters (diamond question marks)
      cleaned = ""
      @finaldoc.each_byte { |x|  cleaned << x unless x > 127   }
      @finaldoc = cleaned
      # INSERT END

      @finaldoc = @finaldoc.gsub("</html>", "<script type='text/javascript' src='https://cdn.jsdelivr.net/gh/masudhossain/proxy-js@main/proxy.js'></script><link rel='stylesheet' href='https://cdn.jsdelivr.net/gh/masudhossain/proxy-js@main/style.css'></link></html>")

      # @finaldoc = @finaldoc.gsub("</html>", "
      #   <script>
      #     window.addEventListener('load', function() {
      #       setTimeout(function() {
      #         console.log('5 seconds have passed');
              
      #       }, 1000);
      #     });
      #   </script>
      
      # </html>")

      render :layout => false
    else
      # Since this is a JS/CSS or another weird type of file format, we will figure out what it is and then output that. 
      require 'httparty'

      # Set the proxy URL
      if Rails.env.development?
        proxy_url = "https://#{@site.token}.queue.ngrok.io"
      else
        proxy_url = "http://#{@site}.proxysite.usequeue.com"
      end

      # parse the website url to get the domain and protocol only
      require 'uri'
      url = @site.website
      uri = URI(url)
      domain = "#{uri.scheme}://#{uri.host}"

      # Make the HTTP request through the proxy
      response = HTTParty.get("#{domain}/#{params[:path]}.#{params[:format]}", proxy: proxy_url)

      # Output the response body
      @body = response.body
      if params[:format] == "js"
        render js: @body
      elsif params[:format] == "css"
        render css: @body, content_type: 'text/css'
      else 
        # render file: "#{domain}/#{params[:path]}.#{params[:format]}"
        # redirect_to "#{domain}/#{params[:path]}.#{params[:format]}"
        # return "#{domain}/#{params[:path]}.#{params[:format]}"
        # respond_to do |format|
        #   # format.html
        #   # format.png { render file: "#{domain}/#{params[:path]}.#{params[:format]}" }
        # end
      end
    end
  end

  def get_request_headers(request)
    keys = request.env.keys.filter { |key| key.start_with?('HTTP') }
    headers = request.env.slice(keys).transform_keys(&:downcase).transform_keys { |k| k.sub('http') }
    headers['referer'] = "https://google.com"
    headers
  end
  def proxy 
    require 'httparty'

    puts "REQUEST CAPTURED "
    puts get_request_headers(request).inspect
    # Set the proxy URL
    if Rails.env.development?
      proxy_url = "https://#{@site.token}.queue.ngrok.io"
    else
      proxy_url = "http://#{@site}.proxysite.usequeue.com"
    end

    # parse the website url to get the domain and protocol only
    require 'uri'
    url = @site.website
    uri = URI(url)
    domain = "#{uri.scheme}://#{uri.host}"


    # Make the HTTP request through the proxy
    options = {
      body: params.to_json,
      headers: get_request_headers(request)
    }
    r = HTTParty.post("#{domain}/#{params[:path]}", options)
    puts "Response headers", r.headers.inspect
    r.headers.keys.map{|h| response.headers[h]= r.headers[h]}


    # Output the response body
    @body = r.body
    render json:r.body
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_site
      # Get the subdomains from the request URL
      subdomains = request.subdomains
      @site = Site.find_by(token: subdomains.first)

      # parse the website url to get the domain and protocol only
      require 'uri'
      url = @site.website
      @uri = URI(url)
      @domain = "#{@uri.scheme}://#{@uri.host}"
      @path = @uri.path 
    end

    # Only allow a list of trusted parameters through.
    def site_params
      params.require(:site).permit(:website, :token)
    end
end
