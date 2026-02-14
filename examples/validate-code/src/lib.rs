#![expect(unused)]

use rbx_dom_weak::{Instance, WeakDom, types::Variant, ustr};

enum Error {
    InvalidScripts(Vec<String>),
    DecodeBin(rbx_binary::DecodeError),
    DecodeXml(rbx_xml::DecodeError),
    InvalidFile,
    InvalidProperty,
}

fn get_full_name(dom: &WeakDom, inst: &Instance) -> String {
    let mut insts = Vec::new();
    let mut parent = inst.referent();
    while let Some(p) = dom.get_by_ref(parent) {
        insts.insert(0, p.name.as_str());
        parent = p.parent();
    }
    let mut str = String::with_capacity(insts.iter().fold(0, |acc, s| acc + s.len() + 1) + 13);
    str.push_str("(model root)");
    for s in insts {
        str.push('.');
        str.push_str(s);
    }
    str
}

const SANDBOX_INITIALIZER: &str = "require(game:GetService(\"ServerScriptService\").Init):Init()";

fn is_valid_script(source: &str) -> bool {
    let lines = source.lines();
    let mut in_block_comment = false;
    for l in lines {
        let l = l.trim();
        if l.is_empty() {
            continue;
        } else if l.starts_with("--[[") {
            in_block_comment = true;
            continue;
        } else if l.contains("]]") && in_block_comment {
            in_block_comment = false;
            continue;
        } else if in_block_comment || l.starts_with("--") {
            // `--!` is handled by `--`
            continue;
        } else if l.starts_with(SANDBOX_INITIALIZER) && !in_block_comment {
            return true;
        }
        break;
    }
    false
}

/// Validates a Roblox file (rbxm) to ensure that all scripts
/// have the first line of code as the sandbox initializer.
///
/// Accepts a byte slice representing the rbxm file.
///
/// Returns `Ok(())` if all scripts are valid, `Err` otherwise.
fn validate_file(rbxm: &[u8]) -> Result<(), Error> {
    let dom = if &rbxm[0..9] == b"<roblox!" {
        match rbx_binary::from_reader(rbxm) {
            Ok(dom) => dom,
            Err(err) => return Err(Error::DecodeBin(err)),
        }
    } else if &rbxm[0..18] == b"<roblox version=\"" {
        match rbx_xml::from_reader_default(rbxm) {
            Ok(dom) => dom,
            Err(err) => return Err(Error::DecodeXml(err)),
        }
    } else {
        return Err(Error::InvalidFile)
    };

    let scripts = dom.descendants().filter(|desc| {
        matches!(
            desc.class.as_str(),
            "Script" | "LocalScript" | "ModuleScript"
        )
    });

    let usource = ustr("Source");
    let mut issues = Vec::new();

    for script in scripts {
        match script.properties.get(&usource) {
            Some(Variant::String(source)) => {
                if !is_valid_script(source) {
                    issues.push(get_full_name(&dom, script));
                }
            }
            // This is technically an error (Source is always a String and always exists on Scripts)
            _ => return Err(Error::InvalidProperty),
        }
    }

    if issues.is_empty() {
        Ok(())
    } else {
        Err(Error::InvalidScripts(issues))
    }
}

/// Unit tests to make sure that the validation function works correctly.
#[cfg(test)]
mod tests {
    use super::*;

    fn bool_to_result(b: bool) -> Result<(), ()> {
        if b { Ok(()) } else { Err(()) }
    }

    #[test]
    fn allows_exact_match() -> Result<(), ()> {
        let src = r#"
            -- Comment
            --[[ Block comment
            still block
            ]]
            require(game:GetService("ServerScriptService").Init):Init()
        "#;
        bool_to_result(is_valid_script(src))
    }

    #[test]
    fn denies_initializer_in_comment() -> Result<(), ()> {
        let src = r#"
            -- require(game:GetService("ServerScriptService").Init):Init()
        "#;
        bool_to_result(!is_valid_script(src))
    }

    #[test]
    fn denies_initializer_in_block_comment() -> Result<(), ()> {
        let src = r#"
            --[[
            require(game:GetService("ServerScriptService").Init):Init()
            ]]
        "#;
        bool_to_result(!is_valid_script(src))
    }

    #[test]
    fn denies_other_code_before_initializer() -> Result<(), ()> {
        let src = r#"
            local a = 5
            require(game:GetService("ServerScriptService").Init):Init()
        "#;
        bool_to_result(!is_valid_script(src))
    }

    #[test]
    fn denies_other_code_before_initializer_with_comments() -> Result<(), ()> {
        let src = r#"
            -- test
            --[[ opening
            block ]]
            local a = 1
            require(game:GetService("ServerScriptService").Init):Init()
        "#;
        bool_to_result(!is_valid_script(src))
    }

    #[test]
    fn denies_modified_initializer() -> Result<(), ()> {
        let src = r#"
            --[[funny]] require(game:GetService("ServerScriptService").Init):Init()
        "#;
        bool_to_result(!is_valid_script(src))
    }

    #[test]
    fn denies_initializer_after_empty_lines_and_code() -> Result<(), ()> {
        let src = r#"

            local x = 1

            require(game:GetService("ServerScriptService").Init):Init()
        "#;
        bool_to_result(!is_valid_script(src))
    }

    #[test]
    fn allows_with_many_comments_before() -> Result<(), ()> {
        let src = r#"
            -- line 1
            --[[ multiline
            comment ]]
            -- another comment
            require(game:GetService("ServerScriptService").Init):Init()
        "#;
        bool_to_result(is_valid_script(src))
    }

    #[test]
    fn denies_if_only_comment_lines_present() -> Result<(), ()> {
        let src = r#"
            --[[ nothing here ]]
            -- this is a comment
        "#;
        bool_to_result(!is_valid_script(src))
    }

    #[test]
    fn denies_if_initializer_inside_string_literal() -> Result<(), ()> {
        let src = r#"
            print("require(game:GetService(\"ServerScriptService\").Init):Init()")
        "#;
        bool_to_result(!is_valid_script(src))
    }
}
