<p align="center">
  <img src="icon2.png" alt="SCD Logo" width="150"/>
</p>

# 📁 Smart CD — Enhanced Directory Navigation with History & Fuzzy Search




`smart_cd` (`scd`) is a powerful shell utility that improves your directory navigation experience. With **fuzzy matching**, **usage history**, and **lightweight commands**, `scd` makes jumping to frequently visited directories as easy as typing a few letters. It is lightweight package that uses posix shell so no bash is required.

---

## ⚙️ Installation
1. **Clone the repository:**

    ```bash
    git clone https://github.com/chetaniitbhilai/scd/
    cd scd
    ```

2. **Move the script to your home directory as a hidden file**  
   Rename and move your script file:
   ```bash
   mv smart_cd.sh ~/.smart_cd.sh
   ```

3. **Add it to your shell startup file** (`.bashrc` or `.zshrc`):
   ```bash
   echo 'source ~/.smart_cd.sh' >> ~/.bashrc
   source ~/.bashrc
   ```

   > For Zsh users, use `~/.zshrc` instead of `~/.bashrc`.

---

## 🚀 Features

✅ **Fuzzy Search Navigation**  
Type part of a directory name you’ve visited before, and `scd` will jump to the closest match.

✅ **Directory History Tracking**  
`scd` keeps a log of all visited directories so you can easily revisit them.

✅ **Usage Statistics**  
See how often you access various directories.

✅ **Minimal Command Set**  
Lightweight and fast – perfect for power users.

---

## 📘 Usage

```bash
scd [partial_path]
```

### Available Options

| Command          | Description                                                           |
|------------------|-----------------------------------------------------------------------|
| `scd <name>`     | Fuzzy matches `<name>` to previously visited directories and jumps    |
| `scd -l`         | Lists recently visited directories                                    |
| `scd -c`         | Clears all stored directory history                                   |
| `scd --stats`    | Displays frequency stats of visited directories                       |
| `scd -h` / `--help` | Shows help message                                                 |

---

## 🔍 Fuzzy Search Example

Say you've previously visited:

```
/home/yourname/Documents
```

Now, you can type:
```bash
scd ments
```
and it will **intelligently jump to `/home/yourname/Documents`**.

---

## 🧪 More Examples

- **Navigate using fuzzy match**:
  ```bash
  scd proj
  ```
  Might jump to `/home/user/Work/Projects` if you've visited it before.

- **List visited directories**:
  ```bash
  scd -l
  ```

- **Clear history**:
  ```bash
  scd -c
  ```

- **View usage statistics**:
  ```bash
  scd --stats
  ```

---

## 🗃️ Notes

- `scd` stores your history in `~/.smart_cd_history`
- The script uses simple pattern matching; results improve as you use it more.

---

## 🧼 Uninstall

```bash
rm ~/.smart_cd.sh ~/.smart_cd_history
# And remove the line 'source ~/.smart_cd.sh' from your .bashrc or .zshrc
```

---

## Demo

Check out the demo video showcasing the usage of **Smart CD**:

[Watch the demo_video on YouTube](https://youtu.be/PwYShmxiRbU)




## 🛠️ License

This project is released under the [MIT License](LICENSE).

Feel free to contribute. For queries you can mail at chetan@iitbhilai.ac.in
