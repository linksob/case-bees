###############################DATABASE CREATION#######################################
resource "aws_glue_catalog_database" "db_bees_gold" {
  name = "db_bees_gold"
}

######################################################################################
#####################################ROLE FOR TABLES##################################
resource "aws_iam_role" "lakeformation_user_gold" {
  name = "lakeformation_user_gold"
  assume_role_policy = file("${path.module}/policies/trust/lakeformation_trust.json")

  inline_policy {
    name   = "lakeformation-policy-gold"
    policy = file("${path.module}/policies/policy/lakeformation_policy.json")
  }
}


###################################################################################
############################### GOLD TABLE DEFINITION ###########################
resource "aws_glue_catalog_table" "tb_bees_breweries_gold" {
  name          = "tb_bees_breweries_gold"
  database_name = aws_glue_catalog_database.db_bees_gold.name
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.gold.bucket}/tb_bees_breweries_gold/"
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
      name = "brewery_type"
      type = "string"
    }
    columns {
      name = "city"
      type = "string"
    }
    columns {
      name = "brewery_count"
      type = "int"
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
}

###########################################################################
############################ LAKE FORMATION PERMISSIONS ###################
resource "aws_lakeformation_permissions" "gold_crud" {
  principal = aws_iam_role.lakeformation_user_gold.arn

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
    database_name = aws_glue_catalog_database.db_bees_gold.name
    name          = aws_glue_catalog_table.tb_bees_breweries_gold.name
  }
}
############################################################################
