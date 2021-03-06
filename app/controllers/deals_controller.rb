class DealsController < ApplicationController

  def index
    @best_city_deals_list = Deal.top_deals_by_cities
    @destination = params[:name].nil? ? @best_city_deals_list[0][0] : params[:name]
    @duration = params[:duration].nil? ? 0 : params[:duration].to_i
    @depart_dow_i = params[:depart_dow].blank? ? 9 :  params[:depart_dow].to_i
    @top_deals = Deal.top_deals_by_price_by_cities(@destination, @duration, @depart_dow_i)
    @min_max = calc_min_max(@top_deals)
    @deal_chart = params[:chart_id].nil? ? @top_deals.first : Deal.find(params[:chart_id])
    @city = City.find_by(code: @destination).photo
    @preference = Preference.new
    @user = current_user
    @data = @deal_chart.get_historical.to_json
  end

  def calc_min_max(top_deals)
    all_prices = []
    top_deals.each do |deal| 
      each_deal_prices = deal.get_historical.map { |point| point[1] }
      all_prices << each_deal_prices
    end
    min_price = all_prices.flatten.min
    max_price = all_prices.flatten.max
    return [min_price, max_price]
  end

  def chart
    @deal = Deal.find(params[:id])
    @data = @deal.get_historical.to_json
    puts @data
    respond_to do |format|
      format.html { redirect_to deals_path }
      format.js  # <-- will render `app/views/deals/index.js.erb`
    end
  end


  def show
    @deal = Deal.find(params[:id])
    @min_max = params[:min_max]
    @itineraries = []
  end

  def show_loaded
    @deal = Deal.find(params[:id])

    if params[:key]
      @key = params[:key]
      results = fetch_results_with_session_id(@key)
      @itineraries = results["Itineraries"]
      @legs = results["Legs"]
      @carriers = results["Carriers"]
      @agents = results["Agents"]
      @places = results["Places"]
      puts 'part 1'
    else
      response = call_api(@deal)
      if response.headers[:location].nil?
        while response.headers[:location].nil? do
          response = call_api(@deal)
          sleep 1
        end
      end
      @itineraries = []
      @key = response.headers[:location].split("/").last
    end
  end

  def call_api(deal)
    response = Unirest.post "https://skyscanner-skyscanner-flight-search-v1.p.rapidapi.com/apiservices/pricing/v1.0",
        headers:{
          "Content-Type" => "application/x-www-form-urlencoded",
          "X-RapidAPI-Key" => ENV["RAPID_API_KEY"],
        },
        parameters:{
          "country" => "JP",
          "currency" => "JPY",
          "locale" => "en-US",
          "originPlace" => @deal.origin,
          "destinationPlace" => @deal.destination,
          "outboundDate" => @deal.depart_date.strftime("%Y-%m-%d"),
          "inboundDate" => @deal.return_date.strftime("%Y-%m-%d"),
          "cabinClass" => "economy",
          "adults" => 1,
          "children" => 0,
          "infants" => 0,
          "includeCarriers" => "",
          "excludeCarriers" => "",
          "groupPricing" => "false"
        }
    return response
  end

  def fetch_results_with_session_id(session_id)
    response = Unirest.get("https://skyscanner-skyscanner-flight-search-v1.p.rapidapi.com/apiservices/pricing/uk2/v1.0/#{session_id}?sortType=price&sortOrder=asc&stops=0&pageIndex=0&pageSize=10",
    headers: {
      "Accept" => "application/json",
      "X-RapidAPI-Key" => ENV["RAPID_API_KEY"],
    })
    return response.body
  end


end
