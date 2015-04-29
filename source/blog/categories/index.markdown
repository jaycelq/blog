---
layout: page
title: "Categories"
date: 2013-07-28 23:11
comments: true
sharing: false
footer: true
---

<ul>
{% for item in site.categories %}
    <li>{{ item[0] | category_link }} [ {{ item[1].size }} ]</li>
{% endfor %}
</ul>
