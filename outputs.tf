output "instance_web_ipv4" {
  value = aws_instance.whiskey_web.private_ip
}
output "instance_web2_ipv4" {
  value = aws_instance.whiskey_web2.private_ip
}
output "instance_db_ipv4" {
  value = aws_instance.DB_server.private_ip
}
output "instance_db2_ipv4" {
  value = aws_instance.DB_server2.private_ip
}
output "LB_DNS" {
  value = aws_lb.lb.dns_name
}