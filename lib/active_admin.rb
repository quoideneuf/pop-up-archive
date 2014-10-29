module ActiveAdmin
  module Views
    module Pages
      class Base

        def build_page_content
          build_flash_messages
          div id: "active_admin_content", class: (skip_sidebar? ? "without_sidebar" : "with_sidebar") do
            # swap order so that sidebar renders first
            build_sidebar unless skip_sidebar?
            build_main_content_wrapper
          end
        end
      end
    end
  end
end

