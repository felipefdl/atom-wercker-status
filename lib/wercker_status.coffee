async   = require 'async'
_       = require 'lodash'
git     = require './git'
wercker = require './wercker'

class WerckerStatus
    ctx = null

    init: () ->
        ctx = this
        @set_status('...')
        exec = (err, result) ->
            if err
                ctx.set_status(null)
            else
                ctx.set_status(result)
        async.waterfall [@get_gitparams, @get_wercker_status], exec

    get_gitparams: (cb) ->
        git.get_local_git_config (err, data) ->
            if err
                return ctx.set_status(null)
            cb(null, data)

    get_wercker_status: (gitparams, cb) ->
        wercker.get_applications (err, apps) ->
            return cb(err || 'Applications not found') if err or !apps
            if apps.error?.message == 'Unknown token'
                return atom.config.set('wercker-status.Token', null)
            app = _.first(_.where(apps, {'url': gitparams.url}))
            return cb('App not found') if !app # When don't match with wercker apps

            wercker.get_builds app.id, (err, builds) ->
                return cb(err || 'Builds not found') if err or !builds
                build = _.first(_.where(builds, {"branch": gitparams.branch}))
                return cb('Build not found') if !build
                cb(null, build)

    handle_string: (buildobj) ->
        return "<span>ERROR</span>" if !buildobj.result and !buildobj.status
        if buildobj.result == 'unknown'
            status = buildobj.status
        else
            status = buildobj.result
        href = wercker.mount_url(buildobj.id)
        return "<a href=\"#{href}\" class=\"#{status.toLowerCase()}\">#{status.toUpperCase()}</a>"

    set_status: (status) ->
        $wercker_status = atom.workspaceView.find('#wercker-status')
        return $wercker_status.remove() if !status

        string_status = if typeof status == 'string' then "<span>#{status}</span>" else @handle_string(status)
        string_append = "<span>Wercker:</span> #{string_status}"

        if $wercker_status.length == 0
            atom.workspaceView.statusBar?.prependRight("<div id=\"wercker-status\"></div>")
            $wercker_status = atom.workspaceView.find('#wercker-status')
        else
            $wercker_status.find('a, span').remove()

        $wercker_status.append(string_append)

module.exports = new WerckerStatus
