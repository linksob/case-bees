resource "aws_glue_catalog_database" "db_bees_silver" {
  name = "db_bees_silver"
}

# Silver table
resource "aws_glue_catalog_table" "tb_bees_breweries_silver" {
  name          = "tb_bees_breweries_silver"
  database_name = aws_glue_catalog_database.db_bees_silver.name
  table_type = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.silver.bucket}/tb_bees_breweries_silver/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    compressed    = true
        parameters = {
        "parquet.compression" = "SNAPPY"
    }

    ser_de_info {
      name                  = "parquet"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
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
      name = "country"
      type = "string"
    }
    columns {
      name = "longitude"
      type = "double"
    }
    columns {
      name = "latitude"
      type = "double"
    }
    columns {
      name = "phone"
      type = "string"
    }
    columns {
      name = "website_url"
      type = "string"
    }
  }
    partition_keys {
      name = "transaction_date"
      type = "string"
  }
    partition_keys {
      name = "state_province"
      type = "string"
    }
    partition_keys {
      name = "city"
      type = "string"
    }
  }

# Lake Formation Permissions (CRUD)
resource "aws_iam_role" "lakeformation_user" {
  name = "lakeformation_user"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "*"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_lakeformation_permissions" "silver_crud" {
  principal = aws_iam_role.lakeformation_user.arn

  permissions = [
    "SELECT",
    "INSERT",
    "DELETE",
    "ALTER",
    "DROP",
    "DESCRIBE"
  ]

  permissions_with_grant_option = []

  table {
    database_name = aws_glue_catalog_database.db_bees_silver.name
    name          = aws_glue_catalog_table.tb_bees_breweries_silver.name
  }
}