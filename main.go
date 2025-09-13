// Copyright 2016 Martin Hebnes Pedersen (LA5NTA). All rights reserved.
// Use of this source code is governed by the MIT-license that can be
// found in the LICENSE file.

// A portable Winlink client for amateur radio email.
package main

import (
	"context"
	"embed"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/la5nta/pat/api"
	"github.com/la5nta/pat/app"
	"github.com/la5nta/pat/cfg"
	"github.com/la5nta/pat/cli"
	"github.com/la5nta/pat/internal/buildinfo"
	"github.com/la5nta/pat/internal/directories"

	"github.com/spf13/pflag"
)

//go:embed web/dist/**
var embeddedFS embed.FS

func init() {
	api.EmbeddedFS = embeddedFS

	pflag.Usage = func() {
		fmt.Fprintf(os.Stderr, "%s is a client for the Winlink 2000 Network.\n\n", buildinfo.AppName)
		fmt.Fprintf(os.Stderr, "Usage:\n  %s [options] command [arguments]\n", os.Args[0])

		fmt.Fprintln(os.Stderr, "\nCommands:")
		for _, cmd := range cli.Commands {
			fmt.Fprintf(os.Stderr, "  %-15s %s\n", cmd.Str, cmd.Desc)
		}

		fmt.Fprintln(os.Stderr, "\nOptions:")
		optionsSet(&app.Options{}).PrintDefaults()
		fmt.Fprint(os.Stderr, "\n")
	}
}

func main() {
	cmd, options, args, err := cli.FindCommand(os.Args)
	if err != nil {
		pflag.Usage()
		os.Exit(1)
	}
	var opts app.Options
	optionsSet(&opts).Parse(options)

	if len(args) == 0 {
		args = append(args, "")
	}
	switch args[0] {
	case "--help", "-help", "help", "-h":
		cmd.PrintUsage()
		os.Exit(1)
	}
	if cmd.Str == "help" {
		cli.HelpHandle(args)
		return
	}

	sig := notifySignals()

	// Run app in a loop for config reloading
	for runApp(opts, cmd, args, sig) {
		fmt.Fprintln(os.Stderr, "Reloading application...")
	}
}

func runApp(opts app.Options, cmd app.Command, args []string, sig <-chan os.Signal) bool {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	a := app.New(opts)
	defer a.Close()

	// Graceful shutdown/reload handling.
	shouldReload := make(chan bool, 1)
	done := make(chan struct{})
	a.OnReload = func() error {
		// Avoid reloading of bad config
		if _, err := app.LoadConfig(opts.ConfigPath, cfg.DefaultConfig); err != nil {
			return fmt.Errorf("bad config: %v", err)
		}
		cancel()
		shouldReload <- true
		return nil
	}
	go func() {
		defer close(shouldReload)
		dirtyDisconnectNext := false // So we can do a dirty disconnect on the second interrupt
		for {
			select {
			case s := <-sig:
				switch {
				case isSIGHUP(s):
					if err := a.Reload(); err != nil {
						log.Printf("Ignoring live reload due to error: %v", err)
						continue
					}
					return
				default:
					if ok := a.AbortActiveConnection(dirtyDisconnectNext); ok {
						dirtyDisconnectNext = !dirtyDisconnectNext
						continue
					}
					cancel()
					shouldReload <- false
					return
				}
			case <-done:
				return
			}
		}
	}()

	// Run the app
	a.Run(ctx, cmd, args)
	close(done)
	return <-shouldReload
}

func optionsSet(opts *app.Options) *pflag.FlagSet {
	set := pflag.NewFlagSet("options", pflag.ExitOnError)

	set.StringVar(&opts.MyCall, "mycall", "", "Your callsign (winlink user).")
	set.StringVarP(&opts.Listen, "listen", "l", "", "Comma-separated list of methods to listen on (e.g. ardop,telnet,ax25).")
	set.BoolVarP(&opts.SendOnly, "send-only", "s", false, "Download inbound messages later, send only.")
	set.BoolVarP(&opts.RadioOnly, "radio-only", "", false, "Radio Only mode (Winlink Hybrid RMS only).")
	set.BoolVar(&opts.IgnoreBusy, "ignore-busy", false, "Don't wait for clear channel before connecting to a node.")

	defaultMBox := filepath.Join(directories.DataDir(), "mailbox")
	defaultFormsPath := filepath.Join(directories.DataDir(), "Standard_Forms")
	defaultConfigPath := filepath.Join(directories.ConfigDir(), "config.json")
	defaultPrehooksPath := filepath.Join(directories.ConfigDir(), "prehooks")
	defaultLogPath := filepath.Join(directories.StateDir(), strings.ToLower(buildinfo.AppName+".log"))
	defaultEventLogPath := filepath.Join(directories.StateDir(), "eventlog.json")
	defaultScriptsPath := filepath.Join(directories.DataDir(), "scripts")
	set.StringVar(&opts.MailboxPath, "mbox", defaultMBox, "Path to mailbox directory.")
	set.StringVar(&opts.FormsPath, "forms", defaultFormsPath, "Path to forms directory.")
	set.StringVar(&opts.ConfigPath, "config", defaultConfigPath, "Path to config file.")
	set.StringVar(&opts.PrehooksPath, "prehooks", defaultPrehooksPath, "Path to prehooks")
	set.StringVar(&opts.LogPath, "log", defaultLogPath, "Path to log file. The file is truncated on each startup.")
	set.StringVar(&opts.EventLogPath, "event-log", defaultEventLogPath, "Path to event log file.")
	set.StringVar(&opts.ScriptsPath, "scripts", defaultScriptsPath, "Path to script file directory.")

	return set
}
