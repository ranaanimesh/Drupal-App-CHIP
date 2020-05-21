output rds-db-passwd {
  value = random_password.rds_password.result
}
