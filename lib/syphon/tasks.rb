namespace :syphon do
  task :build, [:indices] => :environment do |t, args|
    require 'set'
    classes = Syphon.index_classes

    if (indices = args[:indices]).present?
      class_names = indices.scan(/\w+/).to_set
      classes.select! { |c| class_names.include?(c.name) }
    end

    n = classes.size
    if n == 0
      if indices
        puts "No index classes found matching '#{indices}'. Available: #{Syphon.index_classes.map(&:name).join(', ')}"
      else
        puts "No index classes"
      end
    else
      classes.each_with_index do |klass, i|
        puts "#{i+1}/#{n}: Building #{klass}..."
        klass.build
      end
      puts "Done."
    end
  end
end
