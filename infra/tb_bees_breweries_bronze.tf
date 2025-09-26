#DATABASE CREATION
resource "aws_glue_catalog_database" "db_bees_bronze" {
  name = "db_bees_bronze"
}

# ROLE FOR LAKE FORMATION
resource "aws_iam_role" "lakeformation_user_bronze" {
  name = "lakeformation_user_bronze"
  assume_role_policy = file("${path.module}/policies/trust/lakeformation_trust.json")
}

resource "aws_iam_policy" "lakeformation_policy_bronze" {
  name   = "lakeformation-policy-bronze"
  policy = file("${path.module}/policies/policy/lakeformation_policy.json")
}

resource "aws_iam_role_policy_attachment" "lakeformation_policy_attach_bronze" {
  role       = aws_iam_role.lakeformation_user_bronze.name
  policy_arn = aws_iam_policy.lakeformation_policy_bronze.arn
}

############################### BRONZE TABLE DEFINITION ###########################
resource "aws_glue_catalog_table" "tb_bees_breweries_bronze" {
  name          = "tb_bees_breweries_bronze"
  database_name = aws_glue_catalog_database.db_bees_bronze.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification = "json"
    EXTERNAL       = "TRUE"
  }

  storage_descriptor {
    location      = "s3://bees-brewery-data-bronze/bronze/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "ignore.malformed.json" = "true"
      }
    }
    columns {
      name = "id"
      type = "string"
    }
    columns {
      name = "name"
      type = "string"
    }
    columns {
      name = "brewery_type"
      type = "string"
    }
    columns {
      name = "address_1"
      type = "string"
    }
    columns {
      name = "address_2"
      type = "string"
    }
    columns {
      name = "address_3"
      type = "string"
    }
    columns {
      name = "city"
      type = "string"
    }
    columns {
      name = "state_province"
      type = "string"
    }
    columns {
      name = "postal_code"
      type = "string"
    }
    columns {
      name = "country"
      type = "string"
    }
    columns {
      name = "longitude"
      type = "string"
    }
    columns {
      name = "latitude"
      type = "string"
    }
    columns {
      name = "phone"
      type = "string"
    }
    columns {
      name = "website_url"
      type = "string"
    }
    columns {
      name = "created_at"
      type = "string"
    }
    columns {
      name = "updated_at"
      type = "string"
    }
  }
  partition_keys {
    name = "transaction_date"
    type = "string"
  }
}
#############################################################################