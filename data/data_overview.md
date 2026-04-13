# Java Datagen Data Configuration

This directory contains the complete Java Datagen data configuration for the River Hotels workshop, including generators, schemas, connections, and the main configuration files. The setup uses Java Datagen's modular approach with the [`loadJsonFile` feature](https://docs.shadowtraffic.io/functions/loadJsonFile/) for maintainable and reusable data generation; that link points at documentation for the predecessor ShadowTraffic product, which defined the JSON DSL patterns this toolchain still follows.

## Directory Structure

```sh
data/
├── java-datagen-configuration.json           # Main configuration (e.g. self-service / per-account path)
├── java-datagen-configuration-workshop.json  # Entry config for shared workshop VM (instructor-led)
├── generators/                               # Data generator configurations
│   ├── customer_generator.json
│   ├── hotel_generator.json
│   ├── clickstream_generator_historical.json
│   ├── clickstream_generator_streaming.json
│   ├── booking_generator_historical.json
│   ├── booking_generator_streaming.json
│   ├── review_generator_historical.json
│   ├── review_generator_streaming.json
│   └── content/                       # Text content for generators
│       ├── hotel_descriptions_airport.json
│       ├── hotel_descriptions_economy.json
│       ├── hotel_descriptions_extended_stay.json
│       ├── hotel_descriptions_luxury.json
│       ├── hotel_descriptions_resort.json
│       ├── review_text_choices_1_star.json
│       ├── review_text_choices_2_star.json
│       ├── review_text_choices_3_star.json
│       ├── review_text_choices_4_star.json
│       └── review_text_choices_5_star.json
├── schemas/                           # Avro schema definitions
│   ├── booking_schema.avsc
│   ├── clickstream_schema.avsc
│   └── review_schema.avsc
└── connections/                       # Connection configurations (populated by Terraform)
```

## Configuration Files

### Main Configuration

- **`java-datagen-configuration.json`** - Orchestrates all generators using a three-stage approach: seed data → historical data → streaming data
- **`java-datagen-configuration-workshop.json`** - Entry configuration deployed to shared workshop infrastructure alongside instructor-led generator paths
- **No license file** - Java Datagen does not require a license env file (unlike the predecessor ShadowTraffic image). For optional local environment overrides, you can use `data/.datagen.env`; see `data-generator/run.sh`.

### Terraform-Managed Files

Several critical files are automatically generated and destroyed by Terraform during infrastructure provisioning:

#### Auto-Generated Files

- **`connections/postgres.json`** - PostgreSQL database connection with dynamic host IP and credentials
- **`connections/confluent.json`** - Confluent Cloud connection with API keys, bootstrap servers, and schema registry URLs

#### Why Terraform Management?

These files require numerous resource values and IDs from other Terraform-managed cloud resources (AWS EC2 instances running PostgreSQL, Confluent clusters, API keys, etc.) that need to be dynamically interpolated. Rather than requiring manual configuration with complex resource references, Terraform automatically:

1. **Generates** these files during `terraform apply` with proper resource interpolation
2. **Destroys** these files during `terraform destroy` for clean teardown
3. **Updates** connection details if infrastructure changes

This approach eliminates manual configuration errors and ensures the Java Datagen configuration always has current, valid connection information from the actual provisioned resources.

## Generators

### Data Source Generators

#### PostgreSQL Database Generators

- **`customer_generator.json`** - Generates 1,000 customer records with contact information
- **`hotel_generator.json`** - Generates 30 hotel properties across 9 countries with category-based descriptions

##### Hotel Categories

The hotel generator creates properties across 5 categories, each with dedicated description content:

| Category | Description File |
|----------|-----------------|
| Economy | `hotel_descriptions_economy.json` |
| Extended Stay | `hotel_descriptions_extended_stay.json` |
| Luxury | `hotel_descriptions_luxury.json` |
| Resort | `hotel_descriptions_resort.json` |
| Airport | `hotel_descriptions_airport.json` |

Each hotel is randomly assigned a category, and the description is selected from the corresponding category-specific content file to ensure realistic, contextually appropriate hotel descriptions.

#### Kafka Topic Generators

- **`clickstream_generator_historical.json`** - Generates 3,000 historical website interaction events over the past 8 weeks
- **`clickstream_generator_streaming.json`** - Produces real-time clickstream events every 10-15 seconds
- **`booking_generator_historical.json`** - Generates 400 historical booking records with realistic date relationships
- **`booking_generator_streaming.json`** - Produces streaming booking events every 45-60 seconds
- **`review_generator_historical.json`** - Generates 200 historical hotel reviews linked to hotels via `hotel_id` lookup
- **`review_generator_streaming.json`** - Produces streaming reviews every 100-150 seconds linked to hotels via `hotel_id` lookup

### Content Resources

The `generators/content/` directory contains text content used by generators:

#### Review Text Files

Rating-specific review text files ensure sentiment matches numeric ratings:

- **`review_text_choices_1_star.json`** - Very bad experiences (10% frequency)
- **`review_text_choices_2_star.json`** - Somewhat bad experiences (20% frequency)
- **`review_text_choices_3_star.json`** - OK experiences (30% frequency)
- **`review_text_choices_4_star.json`** - Pretty good experiences (25% frequency)
- **`review_text_choices_5_star.json`** - Great experiences (15% frequency)

#### Hotel Description Files

Category-specific hotel descriptions ensure appropriate marketing copy for each property type:

- **`hotel_descriptions_airport.json`** - Convenient, transit-focused descriptions
- **`hotel_descriptions_economy.json`** - Budget-friendly, value-focused descriptions
- **`hotel_descriptions_extended_stay.json`** - Home-like amenities, long-term comfort descriptions
- **`hotel_descriptions_luxury.json`** - Premium, exclusive experience descriptions
- **`hotel_descriptions_resort.json`** - Vacation, relaxation-focused descriptions

## Schemas

Avro schema files define the structure for Kafka topics and ensure type safety:

### `booking_schema.avsc`

Defines the booking event structure with fields:

- `booking_id`, `customer_email`, `hotel_id`
- `check_in`, `check_out`, `occupants`, `price`
- `created_at` (with Flink timestamp precision)

### `clickstream_schema.avsc`

Defines website interaction events with fields:

- `activity_id`, `customer_email`, `hotel_id`
- `action`, `event_duration`, `url`
- `created_at` (with Flink timestamp precision)

### `review_schema.avsc`

Defines hotel review events with fields:

- `review_id`, `hotel_id`
- `review_rating`, `review_text`
- `created_at` (with Flink timestamp precision)

## Connections

The `connections/` directory contains auto-generated connection files managed by Terraform:

### Connection Files

- **`postgres.json`** - PostgreSQL database connection for customer and hotel data with dynamic AWS EC2 instance details
- **`confluent.json`** - Confluent Cloud connection for Kafka topic streaming with live API keys and cluster endpoints

### Terraform Integration

These connection files are automatically managed through the Terraform lifecycle:

```hcl
# Example from modules/data-generator/main.tf
resource "local_file" "postgres_connection" {
  content = jsonencode({
    kind : "postgres"
    tablePolicy : "create"
    connectionConfigs : {
      host : var.postgres_hostname
      port : var.postgres_port
      username : var.postgres_username
      password : var.postgres_password
      db : var.postgres_database
    }
  })
  filename = "${var.output_path}/postgres.json"
}
```

#### Benefits

- **Dynamic Values**: Automatically includes actual resource IDs, IPs, and API keys from provisioned infrastructure
- **No Manual Updates**: Connection details stay current as infrastructure changes
- **Clean Lifecycle**: Files are created during `terraform apply` and removed during `terraform destroy`
- **Error Prevention**: Eliminates manual transcription errors between Terraform outputs and Java Datagen configuration

## Key Features

### Advanced Data Generation

- **Variable-based Date Logic**: Booking generators ensure `CHECK_OUT` is 2-5 days after `CHECK_IN`
- **Realistic Booking Patterns**: Historical bookings created 2-21 days before `CHECK_IN`
- **Unique Booking References**: Reviews use sequential booking ID references to ensure no duplicate reviews per booking
- **Customer Behavior Modeling**: 80% of activities/bookings from repeat customers
- **Timestamp Formatting**: All date fields use proper formatting with `decimals: 0`
- **Category-Based Content**: Hotel descriptions are matched to property categories (Economy, Extended Stay, Luxury, Resort, Airport)

### Hotel-Linked Reviews

Reviews are linked directly to hotels via `hotel_id` using a lookup against `hotel_generator_historical`. This decoupled design means reviews are independent of bookings — a review references the hotel where the guest stayed, not a specific booking record.

This approach:

- Simplifies the data model by removing the booking-to-review dependency
- Allows the `reviews_with_sentiment` Flink CTAS to join reviews directly with the hotel dimension table via a temporal join on `hotel_id`, avoiding the need to route through `denormalized_hotel_bookings`
- Enables multiple reviews per hotel (realistic for hospitality industry)
- Eliminates the race condition where streaming reviews would need to wait for concurrent booking data

### Rating-Based Review System

- **Sentiment-Rating Alignment**: Each rating (1-5 stars) has dedicated text files with matching sentiment
- **Realistic Distribution**: Weighted frequencies create believable customer feedback patterns
- **Switch-Based Selection**: Intelligent text selection based on numeric rating values

## Rating-Based Review Text System

The review generators implement a sophisticated rating-based text selection system:

### Rating Scale Implementation

| Rating | Sentiment | Frequency | Example Language |
|--------|-----------|-----------|------------------|
| 1 Star | Very bad experiences | 10% | "absolutely dreadful", "complete disaster", "appalling standards" |
| 2 Stars | Somewhat bad experiences | 20% | "disappointing aspects", "didn't quite match expectations" |
| 3 Stars | OK experiences | 30% | "perfectly adequate", "met basic expectations" |
| 4 Stars | Pretty good experiences | 25% | "very pleasant stay", "exceeded expectations" |
| 5 Stars | Great experiences | 15% | "exceptional", "outstanding", "exceeded all expectations" |

#### Distribution Notes

- **Consistent across generators**: Both historical and streaming use identical frequency distributions
- **Realistic pattern**: 4-star reviews (25%) more common than perfect 5-star reviews (15%)
- **Balanced spectrum**: Covers full range from very negative to exceptional experiences

### Technical Implementation

```json
"localConfigs": {
    "avroSchemaHint": {
        "value": {
            "type": "record",
            "name": "ReviewEvent",
            "fields": [
                {"name": "review_id", "type": "string"},
                {"name": "review_text", "type": "string"}
            ]
        }
    }
},
"varsOnce": {
    "oneStarTexts": { "_gen": "loadJsonFile", "file": "/home/data/generators/content/review_text_choices_1_star.json" },
    "twoStarTexts": { "_gen": "loadJsonFile", "file": "/home/data/generators/content/review_text_choices_2_star.json" }
    // ... (3-5 star text files loaded once)
},
"value": {
    "REVIEW_RATING": {
        "_gen": "weightedOneOf",
        "choices": [
            { "weight": 10, "value": 1 },
            { "weight": 20, "value": 2 }
            // ... (weights 30, 25, 15 for ratings 3, 4, 5)
        ]
    },
    "REVIEW_TEXT": {
        "_gen": "weightedOneOf",
        "choices": [
            { "weight": 10, "value": { "_gen": "oneOf", "choices": { "_gen": "var", "var": "oneStarTexts" }}},
            { "weight": 20, "value": { "_gen": "oneOf", "choices": { "_gen": "var", "var": "twoStarTexts" }}}
            // ... (matching weights for 3-5 star texts)
        ]
    }
}
```

## Data Generation Stages

1. **Stage 0: Configuration**
   1. The `java-datagen-configuration.json` file contains a three-sequential-stage approach to generate both a batch of historical data and periodic ongoing streaming data
   2. Connections to PostgreSQL and Confluent Cloud are prebuilt
2. **Stage 1: Seed Data (PostgreSQL Database)**
   1. The `customer_generator` creates 1,000 customer records with timestamps of ~10 weeks ago
   2. The `hotel_generator` creates 30 hotel records across 9 countries with category-based descriptions and timestamps of ~10 weeks ago
3. **Stage 2: Historical Data (Kafka Topics)**
   1. **Clickstream Generator (Historical)** - Generates 3,000 clickstream events with random timestamps over the past ~8 weeks
   2. **Booking Generator (Historical)** - Generates 400 booking records with random timestamps over the past ~8 weeks
   3. **Review Generator (Historical)** - Generates 200 hotel reviews linked to hotels via `hotel_id` lookup, with timestamps over the past ~8 weeks
4. **Stage 3: Streaming Data (Kafka Topics)**
   1. **Clickstream Generator (Streaming)** - Produces messages every 10-15 seconds to the `clickstream` topic with a maximum of 125 events
      - References customer emails and hotel IDs from PostgreSQL data
      - 80% of clickstream activity come from existing customers, 20% from anonymous users
   2. **Booking Generator (Streaming)** - Produces messages every 45-60 seconds to the `bookings` topic with a maximum of 20 events
      - References customer emails and hotel IDs from PostgreSQL data
   3. **Review Generator (Streaming)** - Produces messages every 100-150 seconds to the `reviews` topic up to a max of 10 events
      - Includes all review ratings from 1-5 stars with weighted distribution
      - References hotels via `hotel_id` lookup from `hotel_generator_historical`

### Stage Dependencies

The three-stage approach ensures proper data dependencies:

- **Stage 1** completes first, populating PostgreSQL with customer and hotel master data
- **Stage 2** runs after Stage 1, allowing historical Kafka events to reference existing master data via lookups
- **Stage 3** runs after Stage 2, producing ongoing streaming events that also reference master data

## Usage

### Running Java Datagen

Prefer the repo helper, which builds `workshop-datagen:latest` from `data-generator/` if needed, mounts `data/`, exposes the health port, and optionally loads `data/.datagen.env`:

```sh
# From workshop-tableflow-databricks/ (repository root for the labs)
./data-generator/run.sh
```

Equivalent manual `docker run` (no license file; image tag matches Terraform defaults such as `public.ecr.aws/v3a9u0p7/workshop-datagen:latest`):

```sh
docker run --rm -p 9400:9400 -v "$(pwd)/data:/home/data" public.ecr.aws/v3a9u0p7/workshop-datagen:latest --config /home/data/java-datagen-configuration.json
```

For shared workshop VMs, Terraform typically uses `--config /home/data/java-datagen-configuration-workshop.json` instead.

### Docker Command Breakdown

| Component | Purpose |
|-----------|---------|
| `docker run` | Starts a new Docker container |
| `-v "$(pwd)/data:/home/data"` | Mounts local `data/` directory to container for file access |
| `-p 9400:9400` | Exposes the datagen health endpoint (see `data-generator/run.sh`) |
| `public.ecr.aws/v3a9u0p7/workshop-datagen:latest` | Published Java Datagen image (build locally as `workshop-datagen:latest` via `data-generator/` if you prefer) |
| `--config /home/data/java-datagen-configuration.json` | Points to main configuration file for local/self-service-style layouts |

The predecessor ShadowTraffic distribution used `shadowtraffic/shadowtraffic` on Docker Hub with a separate license env file; that stack is not used here.

### Benefits of This Configuration

1. **Maintainability**: Modular files make individual components easy to modify
2. **Reusability**: Generators can be reused across different configurations
3. **Type Safety**: Avro schemas ensure data consistency and compatibility
4. **Realistic Data**: Rating-based text selection creates believable synthetic data
5. **Scalability**: Three-stage approach handles both historical and streaming scenarios
6. **Operations**: No license env file; optional `data/.datagen.env` for local overrides

For Docker-oriented notes on the old commercial image, the [predecessor ShadowTraffic cheat sheet](https://docs.shadowtraffic.io/cheatsheet/#docker-commands) remains a useful historical reference but does not describe this workshop image.

## Business Value

This configuration generates realistic River Hotels data for testing AI-powered marketing pipelines:

- **Customer interactions** through website clickstream events
- **Booking transactions** with proper temporal relationships
- **Review feedback** with sentiment matching ratings
- **Multi-system integration** across PostgreSQL, Kafka, and analytics platforms

The synthetic data enables comprehensive testing of real-time AI marketing systems without requiring production data or complex customer privacy considerations.
