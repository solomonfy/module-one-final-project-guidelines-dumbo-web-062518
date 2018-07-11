require 'rest-client'
require 'json'
require 'pry'
# These methods are used to scrape the drink instructions and ingredients from the cocktail DB site.


def get_drink_hash(drink)
  #gets the drink hash
  all_drinks = RestClient.get('https://www.thecocktaildb.com/api/json/v1/1/search.php?s=' + drink.to_s)
  wrapper_hash = JSON.parse(all_drinks)
  wrapper_hash["drinks"].kind_of?(Array) ? drink_hash = wrapper_hash["drinks"][0] : drink_hash = wrapper_hash["drinks"]
end

def get_ingredients(drink_hash)
  return [] if drink_hash == nil
  ingredient_array = []
  loop_counter = 1
  until loop_counter == 16
    break if drink_hash["strIngredient#{loop_counter}"] == ""
    ingredient_array << drink_hash["strIngredient#{loop_counter}"]
    loop_counter += 1
  end
  return ingredient_array
end

def get_instructions(drink_hash)
  return "" if drink_hash == nil
  instruction_string = drink_hash["strInstructions"]
end

def get_ingredients_from_drink_names(drink_names_array)
  combined_ingredient_array = []
  drink_names_array.each do |drink_name|
    combined_ingredient_array << get_ingredients(get_drink_hash(drink_name)).compact
    combined_ingredient_array = combined_ingredient_array.flatten
    combined_ingredient_array = combined_ingredient_array.uniq
  end
  combined_ingredient_array
end

def ingredient_seed(drink_names_array)
  # Takes an array of drink names, finds the drink's ingredients, and creates database entries of the ingredients.
  master_list_array = get_ingredients_from_drink_names(drink_names_array)
  master_list_array.each do |ingredient|
    Ingredient.find_or_create_by(name: ingredient)
  end
end

def build_drinks_and_instructions(drink_names_array)
# Takes an array of drink names and returns a hash comprising the drink name and the recipe instructions.
  master_drinks_hash = {}
  drink_names_array.each do |drink_name|
    master_drinks_hash[drink_name] = get_instructions(get_drink_hash(drink_name))
  end
  master_drinks_hash
end

def drink_and_instruction_seed(drink_names_array)
  # Takes an array of drink names and creates database entries containing the drink name and the recipe instructions.
  master_drinks_hash = build_drinks_and_instructions(drink_names_array)
  master_drinks_hash.each do |key, value|
    Drink.find_or_create_by(name: key, instructions: value)
  end
end

def get_drink_id_and_ingredient_ids(drink_name_string)
# Takes a drink name string and returns an id_hash containing the drink ID and an array of the ingredient IDs.
# Get the drink id from the database
  drink_id = Drink.id_from_name(drink_name_string)
# Get the ingredients from the website
  ingredient_array = get_ingredients(get_drink_hash(drink_name_string))
# Get the ingredient ids from the database
  ingredient_ids = []
  ingredient_array.each do |ingredient|
    ingredient_ids << Ingredient.id_from_name(ingredient)
  end
  return {table1_id: drink_id, table2_ids: ingredient_ids}
end

def make_joiner_entries(table1, table2, id_hash)
  # creates association entries in the joiner table between the table 1 ID and the table 2 IDs
  # id_hash MUST BE in the following format: {:table1_id=>1, :table2_ids=>[1, 2, 3]}
  id_hash[:table2_ids].each do |table2_id|
    table2s = table2.name.downcase.pluralize
    if table1.find_by(id: id_hash[:table1_id]).send(table2s).find {|i| i.id == table2_id} == nil
      puts "Creating new association!"
      table1.find_by(id: id_hash[:table1_id]).send(table2s) << table2.find_by(id: table2_id)
    else
      puts "Association already exists!"
    end
  end
end

def bulk_joiner
  cocktail_array = ["Martini","Manhattan","Old Fashioned","Mint Julep","Mojito","Margarita","Daiquiri","Tom Collins","Martinez","Brandy Cocktail","Brandy Daisy","Sidecar","Whiskey Sour","Sazerac","New Orleans Fizz","French 75","Negroni","Brandy Alexander","Bronx Cocktail"]

  cocktail_array.each do |cocktail|
    make_joiner_entries(Drink, Ingredient, get_drink_id_and_ingredient_ids(cocktail))
  end
end
