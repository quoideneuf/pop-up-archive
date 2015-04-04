module Feedjira
  
  module Parser

    class MediaRSSCopyright
      include SAXMachine
      include FeedEntryUtilities

      attribute :url
      value :value

    end

  end

end