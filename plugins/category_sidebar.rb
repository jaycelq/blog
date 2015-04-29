module Jekyll
  class CategoryListTag < Liquid::Tag
    def render(context)
      html = ""
      categories = context.registers[:site].categories.keys
      dir = context.registers[:site].config['category_dir']
      categories.sort.each do |category|
        posts_in_category = context.registers[:site].categories[category].size
        cate_dir = category.to_url
        url =  dir+"/"+ cate_dir
        html << "<li class='category'><a href=' /#{url}/'>#{category} (#{posts_in_category})</a></li>\n"
        # html << "<li class='category'><a href='/blog/categories/#{category.downcase}/'>#{category} (#{posts_in_category})</a></li>\n"
      end
      html
    end
  end
end

Liquid::Template.register_tag('category_sidebar', Jekyll::CategoryListTag)
