xml.instruct! :xml, :version => "1.1"
xml.rates(:date => @date) do
  @items.each do |item|
    xml.item do
      xml.code item.code
      xml.rate item.rate
    end
  end
end

