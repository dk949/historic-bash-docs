import './style.css'
import bash_versions from "./bash_versions.json"

const main = document.getElementById("main") as HTMLDivElement;
const stable_only_el = document.getElementById("stable-only") as HTMLInputElement;
const stable_only_label_el = document.querySelector('label[for="stable-only"]') as HTMLLabelElement;
let stable_only = true;

function parseVer(ver: string): { major: number, is_stable: boolean } {
    ver = ver.substring(5);
    const is_stable = !(ver.includes("beta") || ver.includes("alpha") || ver.includes("rc"));
    const major = parseInt(ver.split(".").shift() as string);
    return { major, is_stable };
}

function updateLabelText() {
    if (stable_only)
        stable_only_label_el.innerText = "Show unstable"
    else
        stable_only_label_el.innerText = "Show only stable"
}

function insertVersions() {
    main.innerHTML = "";
    let last_section = 0;
    const secitons: HTMLElement[] = [];
    for (const { version, date } of bash_versions) {
        const { major, is_stable } = parseVer(version);
        if (stable_only && !is_stable) continue;
        if (major !== last_section) {
            secitons.push(document.createElement("section"))
            secitons[secitons.length - 1].classList.add("flex", "justify-center")
            secitons[secitons.length - 1].innerHTML = `<div><h2 class="text-3xl mt-4 mb-2">Bash ${major}</h2><ul></ul></div>`;
            last_section = major;
        }
        const li = document.createElement("li")
        li.innerHTML = `<span class="text-xl flex justify-between gap-4"><a class="text-amber-500" href="${version}/bashref.html">${version}</a> (${date})</span>`;
        secitons[secitons.length - 1].firstChild?.lastChild?.appendChild(li)
    }

    main.append(...secitons);
}

insertVersions();
updateLabelText();
stable_only_el.addEventListener("change", _ => {
    stable_only = !stable_only_el.checked;
    insertVersions();
    updateLabelText();
});
