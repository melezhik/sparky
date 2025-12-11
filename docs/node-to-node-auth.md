# Node to node authentication


| Method        | Node to node protocol |  Desc                               | Implemented | Maintainance Complexity | Security |
| ------------- | --------------------- | ----------------------------------- | ------------| ----------------------- | --------- 
| shared token  | http                  | shared SPARKY_API_TOKEN per cluster | yes         | easy                    | low      |
| shared token  | https                 | shared SPARKY_API_TOKEN per cluster | yes         | easy                    | medium   |
| ssh/scp       | ssh                   | ssh protocol for node to node comm  | no          | medium                  | high     |
| mtls          | https + mtls          | mutual tls node to node comm        | no          | medium                  | good     |




