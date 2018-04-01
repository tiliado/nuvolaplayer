/*
 * Copyright 2017-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

var Async = {}
Async.nextPromiseId = 1
Async.promises = {}
Async.MAX_PROMISE_ID = 32767

Async.begin = function (func) {
  var ctx = {}
  while (this.promises[this.nextPromiseId]) {
    if (this.nextPromiseId === this.MAX_PROMISE_ID) {
      this.nextPromiseId = 1
    } else {
      this.nextPromiseId++
    }
  }
  this.promises[this.nextPromiseId] = ctx
  ctx.id = this.nextPromiseId
  ctx.promise = new Promise(function (resolve, reject) { ctx.resolve = resolve; ctx.reject = reject })
  try {
    func(ctx)
  } catch (error) {
    ctx.reject(error)
    this.remove(ctx)
  }
  return ctx.promise
}

Async.remove = function (ctx) {
  delete this.promises[ctx.id]
  // Break reference cycles
  delete ctx.promise
  delete ctx.reject
  delete ctx.resolve
}

Async.call = function (path, params) {
  return this.begin((ctx) => Nuvola._callIpcMethodAsync(path, params || null, ctx.id))
}

Async.respond = function (id, response, error) {
  var ctx = this.promises[id]
  if (ctx) {
    if (error) {
      ctx.reject(error)
    } else {
      ctx.resolve(response)
    }
    this.remove(ctx)
  } else {
    throw new Error('Promise ' + id + ' not found.')
  }
}

Nuvola.Async = Async
