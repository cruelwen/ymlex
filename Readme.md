# Ymlex - 扩展Yml

一个Yml语法的扩展，用于快速生产Yml配置，支持：
* 继承
* 变量替换

## 继承

Yml模板(就是标准的YML)
```yml
a: "a"
b: "b"
c: 
  ca: "ca"
  cb: "cb"
```
继承：
```yml
_inherig: template.yml
a: "a_new"
c: 
  ca: "ca_new"
d: "d_new"
```
结果：
```yml
a: "a_new"
b: "b"
c: 
  ca: "ca_new"
  cb: "cb"
d: "d_new"
```

特性：
* 不只是当前层Merge，而是对所有Hash都会Merge
* 支持递归继承（没处理遇到环的情况）
* 支持在不同层进行多重继承，仅对当前层有效

## 变量替换
```yml
a: /home
b: ${a}/user
c: 
  ca: /var
  cb: ${c.ca}/lib
```
结果
```yml
a: /home
b: /home/user
c: 
  ca: /var
  cb: /var/lib
```

