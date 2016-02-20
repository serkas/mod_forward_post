# mod_forward_post
Ejabberd module for message forwarding as POST request to external server API

Written for ejabberd 16.01.124.

## Example of embeding to installed ejabberd server

You need ejabberd source files. 

```
erlc -o ebin -I include -pa /lib/fast_xml-1.1.3 src/mod_forward_post.erl
cp ebin/mod_forward_post.beam /lib/ejabberd-16.01.124/ebin/ 
```
