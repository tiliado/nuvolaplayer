/*
 * Copyright 2014-2019 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * Creates new object from prototype and mixins.
 *
 * Creates new object that will have `proto` as its prototype and will be extended with properties
 * from all specified `mixins`. This is similar to creating a subclass in class-based inheritance.
 * See @link{$object} for instance object creation. Prototype object names are in `UpperCamelCase`.
 *
 * @param Object|null proto    object prototype or null to use `Object`
 * @param Object mixins...     mixins objects
 * @return new prototype object
 *
 * ```
 * var Building = Nuvola.$prototype(null)
 *
 * Building.$init = function (address) {
 *   this.address = address
 * }
 *
 * Building.printAddress = function () {
 *   console.log(this.address)
 * }
 *
 * var Shop = Nuvola.$prototype(Building)
 *
 * Shop.$init = function (address, goods) {
 *   Building.$init.call(this, address)
 *   this.goods = goods
 * }
 *
 * Shop.printGoods = function() {
 *   console.log(this.goods)
 * }
 * ```
 */
var $prototype = function (proto, mixins) {
  if (proto === undefined) { throw new Error('Proto argument must be specified. Can be null.') }

  var object = Object.create(proto)

  var len = arguments.length
  for (var i = 1; i < len; i++) {
    var mixin = arguments[i]
    for (var name in mixin) { object[name] = mixin[name] }
  }

  return object
}

/**
 * Creates new initialized object from prototype.
 *
 * Creates new object that will have `proto` as its prototype and will be initialized by calling
 * `$init` method with provided arguments `args`. This is similar to creating an instance object
 * from a class in class-based inheritance. Instance object names are in `lowerCamelCase`.
 *
 * @param Object proto            object @link{$prototype|prototype} or null to use `Object`
 * @param variant initArgs...    arguments to pass to the `$init` method
 * @return new initialized object
 *
 * ```
 * var house = Nuvola.$object(Building, 'King Street 1024, London')
 * house.printAddress()
 *
 * var candyShop = Nuvola.$object(Shop, 'King Street 1024, London', 'candies')
 * candyShop.printAddress()
 * candyShop.printGoods()
 * ```
 */
var $object = function (proto, initArgs) {
  if (proto === undefined) { throw new Error('Proto argument must be specified. Can be null.') }

  var object = Object.create(proto)

  if (object.$init) { object.$init.apply(object, [].slice.call(arguments, 1)) }

  return object
}

Nuvola.$object = $object
Nuvola.$prototype = $prototype
