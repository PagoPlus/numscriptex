package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"sort"

	"github.com/Jeffail/gabs/v2"
	"github.com/spf13/cobra"

	"github.com/PagoPlus/numscriptex/internal/analysis"
	"github.com/PagoPlus/numscriptex/internal/interpreter"
	"github.com/PagoPlus/numscriptex/internal/parser"
	"github.com/PagoPlus/numscriptex/internal/utils"
)

type RunInputOpts struct {
	Script    string                       `json:"script"`
	Variables map[string]string            `json:"variables"`
	Meta      interpreter.AccountsMetadata `json:"metadata"`
	Balances  interpreter.Balances         `json:"balances"`
}

func SeverityToString(s analysis.Severity) string {
	switch s {
	case analysis.ErrorSeverity:
		return "error"
	case analysis.WarningSeverity:
		return "warning"
	case analysis.Information:
		return "info"
	case analysis.Hint:
		return "hint"
	default:
		return utils.NonExhaustiveMatchPanic[string](s)
	}
}

func check() {
	dat, err := io.ReadAll(os.Stdin)
	if err != nil {
		os.Stderr.Write([]byte(err.Error()))
		os.Exit(1)
	}

	res := analysis.CheckSource(string(dat))
	sort.Slice(res.Diagnostics, func(i, j int) bool {
		p1 := res.Diagnostics[i].Range.Start
		p2 := res.Diagnostics[j].Range.Start

		return p2.GtEq(p1)
	})

	hasErrors := false
	jsonObj := gabs.New()
	jsonObj.Array("errors")
	for _, d := range res.Diagnostics {
		if d.Kind.Severity() == analysis.ErrorSeverity {
			hasErrors = true
		}
		errLevel := SeverityToString(d.Kind.Severity())

		subJsonObj := gabs.New()
		subJsonObj.Set(d.Range.Start.Line, "line")
		subJsonObj.Set(d.Range.Start.Character, "character")
		subJsonObj.Set(errLevel, "level")
		subJsonObj.Set(d.Kind.Message(), "error")

		jsonObj.ArrayAppend(subJsonObj, "errors")
	}

	if hasErrors {
		jsonObj.Set(false, "valid")
	} else {
		jsonObj.Set(true, "valid")
	}

	fmt.Println(jsonObj.String())
}

var checkCmd = &cobra.Command{
	Use:   "check",
	Short: "Check a numscript file",
	Args:  cobra.NoArgs,
	Run: func(cmd *cobra.Command, args []string) {
		check()
	},
}

func run() {
	opt := RunInputOpts{
		Variables: make(map[string]string),
		Meta:      make(interpreter.AccountsMetadata),
		Balances:  make(interpreter.Balances),
	}

	bytes, err := io.ReadAll(os.Stdin)
	if err != nil {
		panic(err)
	}

	err = json.Unmarshal(bytes, &opt)
	if err != nil {
		panic(err)
	}

	parseResult := parser.Parse(opt.Script)
	if len(parseResult.Errors) != 0 {
		os.Stderr.Write([]byte(parser.ParseErrorsToString(parseResult.Errors, opt.Script)))
		os.Exit(1)
	}

	featureFlags := make(map[string]struct{})
	result, err := interpreter.RunProgram(
		context.Background(),
		parseResult.Value,
		opt.Variables,
		interpreter.StaticStore{
			Balances: opt.Balances,
			Meta:     opt.Meta,
		},
		featureFlags,
	)

	if err != nil {
		os.Exit(1)
	}

	out, err := json.Marshal(result)
	if err != nil {
		os.Exit(1)
	}

	os.Stdout.Write(out)
}

var runCmd = &cobra.Command{
	Use:   "run",
	Short: "Evaluate a numscript file",
	Long:  "Evaluate a numscript file, using the balances, the current metadata and the variables values as input.",
	Run: func(cmd *cobra.Command, args []string) {
		run()
	},
}

var rootCmd = &cobra.Command{
	Use:   "numscript",
	Short: "Numscript cli",
	Long:  "Numscript cli",
	CompletionOptions: cobra.CompletionOptions{
		DisableDefaultCmd: true,
	},
}

func main() {
	rootCmd.AddCommand(checkCmd)
	rootCmd.AddCommand(runCmd)

	if err := rootCmd.Execute(); err != nil {
		os.Stderr.Write([]byte(err.Error()))
		os.Exit(1)
	}
}
