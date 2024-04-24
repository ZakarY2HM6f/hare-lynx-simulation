world_dimension: i32 = 15,
max_populationn_density: i32 = 6,

grass: struct {
    growth_rate: i32 = 1,
    food_storage: i32 = 5,
} = .{},

hare: struct {
    initial_population: i32 = 80,
    max_lifespan: i32 = 10,
    food_storage: i32 = 5,
    initial_food_level: i32 = 3,
    grass_food_value: i32 = 1,
    survival_cost: i32 = 1,
    reproduction_cost: i32 = 2,
} = .{},

lynx: struct {
    initial_population: i32 = 20,
    max_lifespan: i32 = 20,
    food_storage: i32 = 10,
    initial_food_level: i32 = 8,
    hare_food_value: i32 = 2,
    survival_cost: i32 = 1,
    reproduction_cost: i32 = 2,
} = .{},
